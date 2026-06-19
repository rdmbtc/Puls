import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/creator_signal.dart';
import '../market/researched_sources.dart';
import '../market/view_prediction_link.dart';

/// The "Signals" segment of a creator profile.
///
/// • Owner ([isOwner] == true): a "New signal" button, plus their drafts and
///   published signals with edit / publish / analytics actions.
/// • Visitor: published signals as teasers with a paid Unlock action.
///
/// Published signals carry an on-chain attestation badge (links to arcscan).
class SignalsSection extends StatefulWidget {
  const SignalsSection({super.key, required this.creatorUserId, required this.isOwner});

  final String creatorUserId;
  final bool isOwner;

  @override
  State<SignalsSection> createState() => _SignalsSectionState();
}

class _SignalsSectionState extends State<SignalsSection> {
  List<CreatorSignal> _signals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final wallet = WalletServiceScope.of(context);
      final data = await wallet.getSignals(creatorUserId: widget.creatorUserId);
      final list = ((data['signals'] as List?) ?? [])
          .map((e) => CreatorSignal.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() { _signals = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openEditor({CreatorSignal? existing}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SignalEditorSheet(existing: existing),
    );
    if (changed == true) {
      setState(() => _loading = true);
      _fetch();
    }
  }

  Future<void> _publish(CreatorSignal s) async {
    final wallet = WalletServiceScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await wallet.publishSignal(s.id);
      final attested = res['attested'] == true;
      messenger.showSnackBar(SnackBar(
        content: Text(attested
            ? 'Published — attested on Arc ✓'
            : 'Published (on-chain attestation pending)'),
      ));
      setState(() => _loading = true);
      _fetch();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Publish failed: $e')));
    }
  }

  Future<void> _archive(CreatorSignal s) async {
    final wallet = WalletServiceScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await wallet.archiveSignal(s.id);
      messenger.showSnackBar(const SnackBar(content: Text('Signal archived')));
      setState(() => _loading = true);
      _fetch();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Archive failed: $e')));
    }
  }

  Future<void> _unlock(CreatorSignal s) async {
    final wallet = WalletServiceScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await wallet.unlockSignal(s.id);
      if (res['live'] == false) {
        messenger.showSnackBar(SnackBar(
          content: Text('${res['message'] ?? 'Paid unlock activates at launch.'}'),
        ));
        return;
      }
      // Refresh to reveal the thesis.
      setState(() => _loading = true);
      await _fetch();
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Unlocked — thesis revealed ✓')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Unlock failed: $e')));
    }
  }

  void _showAnalytics(CreatorSignal s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AnalyticsSheet(signal: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final children = <Widget>[];

    if (widget.isOwner) {
      children.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New signal'),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.brand,
              side: BorderSide(color: t.brand.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
      children.add(const SizedBox(height: 14));
    }

    if (_error != null) {
      children.add(Text('Couldn\'t load signals.', style: TextStyle(color: t.textMuted, fontSize: 13)));
    } else if (_signals.isEmpty) {
      children.add(_empty(t));
    } else {
      for (final s in _signals) {
        children.add(_SignalCard(
          signal: s,
          isOwner: widget.isOwner,
          onEdit: s.isDraft ? () => _openEditor(existing: s) : null,
          onPublish: s.isDraft ? () => _publish(s) : null,
          onArchive: widget.isOwner && s.status != 'archived' ? () => _archive(s) : null,
          onAnalytics: widget.isOwner ? () => _showAnalytics(s) : null,
          onUnlock: (!widget.isOwner && s.isPublished && !s.unlocked) ? () => _unlock(s) : null,
        ));
        children.add(const SizedBox(height: 10));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _empty(PulsThemeColors t) => Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        width: double.infinity,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        child: Column(
          children: [
            Icon(Icons.auto_awesome_rounded, color: t.textMuted, size: 32),
            const SizedBox(height: 12),
            Text(widget.isOwner ? 'No signals yet' : 'No published signals yet',
                style: TextStyle(color: t.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              widget.isOwner
                  ? 'Publish a premium forecast — it gets attested on Arc and sells per-read.'
                  : 'Premium forecasts from this creator will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textSubtle, fontSize: 12),
            ),
          ],
        ),
      );
}

// ── Signal card ───────────────────────────────────────────────────────────────

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.signal,
    required this.isOwner,
    this.onEdit,
    this.onPublish,
    this.onArchive,
    this.onAnalytics,
    this.onUnlock,
  });

  final CreatorSignal signal;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onPublish;
  final VoidCallback? onArchive;
  final VoidCallback? onAnalytics;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isYes = signal.stance == 'YES';
    final sideColor = isYes ? t.yes : t.no;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: stance + status + price
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sideColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(signal.stance,
                    style: TextStyle(color: sideColor, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: signal.status, t: t),
              const Spacer(),
              Text('\$${signal.priceUsdc.toStringAsFixed(3)}/read',
                  style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(signal.title,
              style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
          if (signal.marketQuestion != null && signal.marketQuestion!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(signal.marketQuestion!,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.textSubtle, fontSize: 12)),
          ],
          if (signal.hasMarketLink) ...[
            const SizedBox(height: 6),
            ViewPredictionLink(slug: signal.marketSlug!),
          ],

          // Confidence / edge / horizon chips
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (signal.confidence != null)
                _metaChip(t, '${(signal.confidence! * 100).round()}% conf'),
              if ((signal.edgeBps ?? 0) > 0) _metaChip(t, '+${signal.edgeBps} bps edge'),
              if (signal.horizon != null && signal.horizon!.isNotEmpty) _metaChip(t, signal.horizon!),
            ],
          ),

          // Body: thesis (if unlocked/owner) or teaser
          const SizedBox(height: 12),
          if (signal.hasThesis)
            Text(signal.thesis!, style: TextStyle(color: t.text, fontSize: 13, height: 1.45))
          else ...[
            Text(signal.teaser ?? 'Premium analysis — unlock to read the full thesis.',
                style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: t.textSubtle),
              const SizedBox(width: 4),
              Text('Locked', style: TextStyle(color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ],

          if (signal.hasSources) ...[
            const SizedBox(height: 12),
            ResearchedSources(sources: signal.sources),
          ],

          // On-chain attestation badge
          if (signal.onchain != null) ...[
            const SizedBox(height: 12),
            _OnchainBadge(onchain: signal.onchain!, t: t),
          ],

          // Actions
          if (onEdit != null || onPublish != null || onArchive != null ||
              onAnalytics != null || onUnlock != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onUnlock != null)
                  _action(t, 'Unlock \$${signal.priceUsdc.toStringAsFixed(3)}', onUnlock!, primary: true),
                if (onPublish != null) _action(t, 'Publish', onPublish!, primary: true),
                if (onEdit != null) _action(t, 'Edit', onEdit!),
                if (onAnalytics != null) _action(t, 'Analytics', onAnalytics!),
                if (onArchive != null) _action(t, 'Archive', onArchive!, danger: true),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(PulsThemeColors t, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: t.border),
        ),
        child: Text(label, style: TextStyle(color: t.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600)),
      );

  Widget _action(PulsThemeColors t, String label, VoidCallback onTap,
      {bool primary = false, bool danger = false}) {
    final fg = danger ? t.no : (primary ? Colors.white : t.text);
    final bg = primary ? t.brand : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary ? t.brand : (danger ? t.no.withValues(alpha: 0.4) : t.border)),
        ),
        child: Text(label, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.t});
  final String status;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'published' => (t.yes, 'Live'),
      'draft' => (PulsColors.amber, 'Draft'),
      _ => (t.textMuted, 'Archived'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _OnchainBadge extends StatelessWidget {
  const _OnchainBadge({required this.onchain, required this.t});
  final SignalOnchain onchain;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final url = onchain.explorer;
        if (url != null) launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: t.brandSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.brand.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 13, color: t.brand),
            const SizedBox(width: 6),
            Text('Attested on Arc', style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Icon(Icons.open_in_new_rounded, size: 11, color: t.brand.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

// ── Analytics sheet ─────────────────────────────────────────────────────────

class _AnalyticsSheet extends StatelessWidget {
  const _AnalyticsSheet({required this.signal});
  final CreatorSignal signal;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final a = signal.analytics;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(signal.title,
              style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat(t, 'Views', '${a?.views ?? 0}'),
              _stat(t, 'Unlocks', '${a?.unlocks ?? 0}'),
              _stat(t, 'Revenue', '\$${(a?.revenueUsdc ?? 0).toStringAsFixed(3)}'),
            ],
          ),
          if (a != null && a.views > 0) ...[
            const SizedBox(height: 12),
            Text('Conversion ${((a.conversion ?? (a.unlocks / a.views)) * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: t.textMuted, fontSize: 12)),
          ],
          if (signal.onchain != null) ...[
            const SizedBox(height: 16),
            _OnchainBadge(onchain: signal.onchain!, t: t),
          ],
        ],
      ),
    );
  }

  Widget _stat(PulsThemeColors t, String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// ── Create / edit sheet ───────────────────────────────────────────────────────

class SignalEditorSheet extends StatefulWidget {
  const SignalEditorSheet({super.key, this.existing});
  final CreatorSignal? existing;

  @override
  State<SignalEditorSheet> createState() => _SignalEditorSheetState();
}

class _SignalEditorSheetState extends State<SignalEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _market;
  late final TextEditingController _teaser;
  late final TextEditingController _thesis;
  late final TextEditingController _horizon;
  late final TextEditingController _price;
  late String _stance;
  double _confidence = 0.6;
  int _edgeBps = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _market = TextEditingController(text: e?.marketQuestion ?? '');
    _teaser = TextEditingController(text: e?.teaser ?? '');
    _thesis = TextEditingController(text: e?.thesis ?? '');
    _horizon = TextEditingController(text: e?.horizon ?? '');
    _price = TextEditingController(text: (e?.priceUsdc ?? 0.001).toString());
    _stance = e?.stance ?? 'YES';
    _confidence = e?.confidence ?? 0.6;
    _edgeBps = e?.edgeBps ?? 0;
  }

  @override
  void dispose() {
    _title.dispose();
    _market.dispose();
    _teaser.dispose();
    _thesis.dispose();
    _horizon.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final thesis = _thesis.text.trim();
    if (title.isEmpty || thesis.isEmpty) {
      setState(() => _error = 'Title and thesis are required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final wallet = WalletServiceScope.of(context);
    final price = double.tryParse(_price.text.trim()) ?? 0.001;
    try {
      if (widget.existing == null) {
        await wallet.createSignal(
          title: title,
          thesis: thesis,
          marketQuestion: _market.text.trim().isEmpty ? null : _market.text.trim(),
          stance: _stance,
          confidence: _confidence,
          edgeBps: _edgeBps,
          horizon: _horizon.text.trim().isEmpty ? null : _horizon.text.trim(),
          teaser: _teaser.text.trim().isEmpty ? null : _teaser.text.trim(),
          priceUsdc: price,
        );
      } else {
        await wallet.updateSignal(widget.existing!.id, {
          'title': title,
          'thesis': thesis,
          'marketQuestion': _market.text.trim(),
          'stance': _stance,
          'confidence': _confidence,
          'edgeBps': _edgeBps,
          'horizon': _horizon.text.trim(),
          'teaser': _teaser.text.trim(),
          'priceUsdc': price,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() { _saving = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(isEdit ? 'Edit signal' : 'New signal',
                  style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              _field(t, 'Title', _title, hint: 'BTC breaks 100k before July'),
              const SizedBox(height: 12),
              _field(t, 'Market question', _market, hint: 'Will BTC close above 100k on Jun 30?'),
              const SizedBox(height: 12),
              // Stance toggle
              Row(
                children: [
                  Text('Stance', style: _labelStyle(t)),
                  const SizedBox(width: 12),
                  _stanceBtn(t, 'YES', t.yes),
                  const SizedBox(width: 8),
                  _stanceBtn(t, 'NO', t.no),
                ],
              ),
              const SizedBox(height: 14),
              Text('Confidence ${(_confidence * 100).round()}%', style: _labelStyle(t)),
              Slider(
                value: _confidence,
                min: 0.5,
                max: 0.99,
                activeColor: t.brand,
                onChanged: (v) => setState(() => _confidence = v),
              ),
              Row(
                children: [
                  Expanded(child: _numField(t, 'Edge (bps)', _edgeBps.toString(),
                      (v) => _edgeBps = int.tryParse(v) ?? 0)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(t, 'Horizon', _horizon, hint: '2026')),
                ],
              ),
              const SizedBox(height: 12),
              _field(t, 'Teaser (public hook)', _teaser, hint: 'Why the line is mispriced…', maxLines: 2),
              const SizedBox(height: 12),
              _field(t, 'Thesis (gated)', _thesis, hint: 'Full analysis readers pay to unlock…', maxLines: 5),
              const SizedBox(height: 12),
              _field(t, 'Price per read (USDC)', _price, hint: '0.001',
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: t.no, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Save draft' : 'Create draft',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Saved as a draft. Publish it to attest on Arc and start selling per-read.',
                style: TextStyle(color: t.textSubtle, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle(PulsThemeColors t) =>
      TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700);

  Widget _stanceBtn(PulsThemeColors t, String value, Color color) {
    final sel = _stance == value;
    return GestureDetector(
      onTap: () => setState(() => _stance = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? color : t.border),
        ),
        child: Text(value, style: TextStyle(color: sel ? color : t.textMuted, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }

  Widget _field(PulsThemeColors t, String label, TextEditingController c,
      {String? hint, int maxLines = 1, TextInputType? keyboard, List<TextInputFormatter>? formatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle(t)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          maxLines: maxLines,
          keyboardType: keyboard,
          inputFormatters: formatters,
          style: TextStyle(color: t.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: t.textSubtle, fontSize: 13),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: t.surfaceRaised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.brand),
            ),
          ),
        ),
      ],
    );
  }

  Widget _numField(PulsThemeColors t, String label, String initial, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle(t)),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: initial),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          style: TextStyle(color: t.text, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: t.surfaceRaised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.brand),
            ),
          ),
        ),
      ],
    );
  }
}
