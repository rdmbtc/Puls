/**
 * Puls Referrals — refer-a-friend, invite mechanic only (F3).
 *
 * Deliberately NO automatic USDC payout (RDM's call: little testnet USDC + the
 * obvious multi-account farming risk that would be a soft spot in the AMA). This
 * is purely an invite mechanic: each user gets a stable referral code + share
 * link, new users claim a code on sign-up, and we surface an "invited N friends"
 * badge so referrers can climb the social board together. No funds move.
 *
 * Data model (see supabase-schema.sql):
 *   referral_codes(user_id PK, code unique, created_at)
 *   referrals(id, referrer_user_id, invitee_user_id unique, code, created_at)
 *
 * Routes:
 *   GET  /api/referrals/me?userId=    my code + share link + invited count/list
 *   POST /api/referrals/claim         { code }  attribute me to the code's owner
 *   GET  /api/referrals/leaderboard   top referrers by invite count
 *   GET  /api/referrals/config        { live, baseUrl }
 *
 * Safety:
 *   - one attribution per invitee ever (unique invitee_user_id), no self-referral.
 *   - verified accounts only (web3 guests are read-only).
 *   - NO USDC payout — purely social. strictLimiter throttles claims.
 *   - optional REFERRALS_ENABLED kill-switch (default ON).
 *
 * Wiring (server.js):
 *   import { registerReferrals } from './lib/referrals.js';
 *   registerReferrals(app, { supabase, authenticateUser, requireVerifiedUser,
 *     strictLimiter, createNotification });
 */

const REFERRALS_ENABLED =
  String(process.env.REFERRALS_ENABLED ?? 'true').toLowerCase() !== 'false';
const REFERRAL_BASE_URL = (process.env.REFERRAL_BASE_URL || 'https://pulsmarket.tech').replace(/\/+$/, '');
// Unambiguous charset (no 0/O/1/I/L) for codes people might type by hand.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LEN = 6;

function randomCode() {
  let c = '';
  for (let i = 0; i < CODE_LEN; i += 1) {
    c += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)];
  }
  return c;
}

function normalizeCode(s) {
  return String(s || '').trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
}

export function registerReferrals(app, deps) {
  const {
    supabase,
    authenticateUser,
    requireVerifiedUser,
    strictLimiter,
    createNotification,
  } = deps;

  const notify = typeof createNotification === 'function'
    ? createNotification
    : async () => {};

  // Resolve display_name + avatar_url for a set of user_ids in one query.
  async function loadAuthors(userIds) {
    const ids = [...new Set(userIds.filter(Boolean))];
    const map = new Map();
    if (ids.length) {
      try {
        const { data } = await supabase
          .from('profiles')
          .select('user_id, display_name, avatar_url')
          .in('user_id', ids);
        for (const p of data || []) map.set(p.user_id, p);
      } catch (e) {
        console.warn('[referrals] author lookup failed:', e.message);
      }
    }
    return (uid) => {
      const p = map.get(uid) || {};
      const isAgent = String(uid || '').includes('agent');
      return {
        userId: uid,
        displayName: (p.display_name || '').trim() || (isAgent ? 'Puls Agent' : 'Puls Trader'),
        avatarUrl:
          p.avatar_url ||
          `https://api.dicebear.com/7.x/${isAgent ? 'bottts' : 'identicon'}/png?size=128&seed=${encodeURIComponent(uid)}`,
        isAgent,
      };
    };
  }

  // Get (or create) the caller's referral code. Retries on the rare collision.
  async function ensureCode(userId) {
    const { data: existing } = await supabase
      .from('referral_codes')
      .select('code')
      .eq('user_id', userId)
      .maybeSingle();
    if (existing && existing.code) return existing.code;

    for (let attempt = 0; attempt < 6; attempt += 1) {
      const code = randomCode();
      const { data, error } = await supabase
        .from('referral_codes')
        .insert({ user_id: userId, code })
        .select('code')
        .single();
      if (!error && data) return data.code;
      // 23505 = unique violation: either the user row now exists, or code clash.
      if (error && error.code === '23505') {
        const { data: row } = await supabase
          .from('referral_codes')
          .select('code')
          .eq('user_id', userId)
          .maybeSingle();
        if (row && row.code) return row.code; // user already had one (race)
        continue; // code clash → try a fresh code
      }
      if (error) throw error;
    }
    throw new Error('Could not allocate a referral code');
  }

  // GET /api/referrals/me — my code, share link, and who I've invited.
  app.get('/api/referrals/me', authenticateUser, requireVerifiedUser, async (req, res) => {
    try {
      if (!REFERRALS_ENABLED) {
        return res.json({ ok: false, live: false, message: 'Referrals are currently disabled.' });
      }
      const userId = req.query.userId; // forced to verified id
      const code = await ensureCode(userId);

      const { data: invited } = await supabase
        .from('referrals')
        .select('invitee_user_id, created_at')
        .eq('referrer_user_id', userId)
        .order('created_at', { ascending: false });
      const rows = invited || [];
      const author = await loadAuthors(rows.map((r) => r.invitee_user_id));

      // Was I myself invited by someone?
      const { data: mine } = await supabase
        .from('referrals')
        .select('referrer_user_id')
        .eq('invitee_user_id', userId)
        .maybeSingle();

      res.json({
        ok: true,
        live: true,
        code,
        link: `${REFERRAL_BASE_URL}/?ref=${code}`,
        invitedCount: rows.length,
        invited: rows.map((r) => ({ ...author(r.invitee_user_id), joinedAt: r.created_at })),
        invitedByMe: !!mine,
      });
    } catch (e) {
      console.error('[referrals] me error:', e.message);
      res.status(500).json({ error: e.message });
    }
  });

  // POST /api/referrals/claim — attribute the caller to a code's owner (once).
  app.post('/api/referrals/claim', authenticateUser, requireVerifiedUser, strictLimiter, async (req, res) => {
    try {
      if (!REFERRALS_ENABLED) {
        return res.json({ ok: false, live: false, message: 'Referrals are currently disabled.' });
      }
      const userId = req.body.userId; // forced to verified id (the invitee)
      const code = normalizeCode(req.body.code);
      if (!code) return res.status(400).json({ error: 'Referral code is required' });

      // Already attributed? Idempotent — report the existing referrer.
      const { data: prior } = await supabase
        .from('referrals')
        .select('referrer_user_id')
        .eq('invitee_user_id', userId)
        .maybeSingle();
      if (prior) {
        return res.json({ ok: true, alreadyClaimed: true, referrer: (await loadAuthors([prior.referrer_user_id]))(prior.referrer_user_id) });
      }

      const { data: owner } = await supabase
        .from('referral_codes')
        .select('user_id')
        .eq('code', code)
        .maybeSingle();
      if (!owner) return res.status(404).json({ error: 'Invalid referral code' });
      if (owner.user_id === userId) {
        return res.status(400).json({ error: "You can't refer yourself" });
      }

      const { error: insErr } = await supabase
        .from('referrals')
        .insert({ referrer_user_id: owner.user_id, invitee_user_id: userId, code });
      if (insErr) {
        // 23505 = someone else won the race → treat as already claimed.
        if (insErr.code === '23505') {
          return res.json({ ok: true, alreadyClaimed: true });
        }
        throw insErr;
      }

      const { count } = await supabase
        .from('referrals')
        .select('id', { count: 'exact', head: true })
        .eq('referrer_user_id', owner.user_id);

      const author = await loadAuthors([owner.user_id, userId]);
      notify(owner.user_id, 'New friend joined! 🎉', `${author(userId).displayName} joined Puls with your invite.`, 'referral_joined')
        .catch((e) => console.warn('[referrals] notif failed:', e.message));

      res.json({ ok: true, claimed: true, referrer: author(owner.user_id), referrerInvitedCount: count || 0 });
    } catch (e) {
      console.error('[referrals] claim error:', e.message);
      res.status(500).json({ error: e.message });
    }
  });

  // GET /api/referrals/leaderboard — top referrers by invite count.
  app.get('/api/referrals/leaderboard', async (req, res) => {
    try {
      const limit = Math.min(100, Math.max(1, parseInt(req.query.limit || '20', 10) || 20));
      const { data: rows, error } = await supabase
        .from('referrals')
        .select('referrer_user_id');
      if (error) throw error;

      const counts = new Map();
      for (const r of rows || []) {
        counts.set(r.referrer_user_id, (counts.get(r.referrer_user_id) || 0) + 1);
      }
      const top = [...counts.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, limit);
      const author = await loadAuthors(top.map(([uid]) => uid));

      res.json({
        ok: true,
        leaders: top.map(([uid, n], i) => ({ rank: i + 1, invitedCount: n, ...author(uid) })),
      });
    } catch (e) {
      console.error('[referrals] leaderboard error:', e.message);
      res.status(500).json({ error: e.message });
    }
  });

  // Config for the UI (live flag, share base URL).
  app.get('/api/referrals/config', (_req, res) => {
    res.json({ live: REFERRALS_ENABLED, baseUrl: REFERRAL_BASE_URL });
  });

  console.log(`[referrals] invite routes registered (enabled: ${REFERRALS_ENABLED ? 'ON' : 'OFF'}, no USDC payout)`);
}
