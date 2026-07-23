// One-shot backfill: populate `sources` for published signals that have none
// (e.g. Striker's early WC signals). Researches each signal's market question on
// the live web and stores up to 4 cited sources, so the signal card shows
// "Researched sources" after unlock.
//
// Usage (backend root, .env present):
//   node scripts/backfill_signal_sources.mjs            # DRY RUN — prints plan
//   node scripts/backfill_signal_sources.mjs --execute  # write sources
import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';
import { researchQuestion } from '../lib/agent_research.js';

const EXECUTE = process.argv.includes('--execute');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

function hasSources(row) {
  return Array.isArray(row.sources) && row.sources.filter((s) => s && s.url).length > 0;
}

const main = async () => {
  const { data, error } = await supabase
    .from('creator_signals')
    .select('id, creator_user_id, title, market_question, sources, status')
    .eq('status', 'published')
    .order('created_at', { ascending: false })
    .limit(200);
  if (error) { console.error('query failed:', error.message); process.exit(1); }

  const need = (data || []).filter((r) => !hasSources(r));
  console.log(`${data.length} published signals; ${need.length} missing sources.`);

  let done = 0;
  for (const sig of need) {
    const q = sig.market_question || sig.title;
    if (!q) continue;
    let sources = [];
    try {
      const res = await researchQuestion(q, 3);
      sources = Array.isArray(res?.sources) ? res.sources.slice(0, 4) : [];
    } catch (e) {
      console.warn(`  research failed for ${sig.id}: ${e.message}`);
    }
    if (!sources.length) { console.log(`  ∅ no sources for "${q.slice(0, 60)}"`); continue; }
    console.log(`  ${EXECUTE ? '✓' : '·'} ${sources.length} sources → "${q.slice(0, 60)}"`);
    if (EXECUTE) {
      const { error: upErr } = await supabase
        .from('creator_signals').update({ sources }).eq('id', sig.id);
      if (upErr) console.warn(`    update failed: ${upErr.message}`);
      else done += 1;
    }
    await new Promise((r) => setTimeout(r, 800)); // be gentle on the research endpoints
  }
  console.log(EXECUTE ? `Backfilled ${done} signals.` : 'DRY RUN — re-run with --execute to write.');
  process.exit(0);
};

main();
