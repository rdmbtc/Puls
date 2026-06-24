import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_snack.dart';
import '../../app/puls_app.dart';

/// Profile → API Keys. Generate a long-lived `pk_live_…` key to connect the
/// **Puls CLI** (or your own agents). The raw key is shown ONCE; the server
/// stores only its hash. Keys can be revoked anytime.
class ApiKeysCard extends StatefulWidget {
  const ApiKeysCard({super.key});

  @override
  State<ApiKeysCard> createState() => _ApiKeysCardState();
}

class _ApiKeysCardState extends State<ApiKeysCard> {
  bool _started = false;
  bool _loading = true;
  bool _busy = false;
  List<dynamic> _keys = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final wallet = WalletServiceScope.of(context);
    try {
      final keys = await wallet.listApiKeys();
      if (mounted) {
        setState(() {
          _keys = keys.where((k) => k['revoked'] != true).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final wallet = WalletServiceScope.of(context);
    try {
      final res = await wallet.generateApiKey(label: 'Puls CLI');
      final key = res['key'] as String?;
      if (mounted && key != null) {
        await _showKeyDialog(key);
        await _load();
      }
    } catch (e) {
      if (mounted) {
        PulsSnack.error(context, '$e'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(String id) async {
    final wallet = WalletServiceScope.of(context);
    try {
      await wallet.revokeApiKey(id);
      if (mounted) {
        setState(() => _keys = _keys.where((k) => k['id'] != id).toList());
        PulsSnack.show(context, 'Key revoked');
      }
    } catch (e) {
      if (mounted) PulsSnack.error(context, '$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showKeyDialog(String key) {
    final t = context.puls;
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.brand.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.vpn_key_rounded, size: 18, color: t.brand),
                    const SizedBox(width: 8),
                    Text('Your new API key',
                        style: TextStyle(
                            color: t.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.border),
                  ),
                  child: SelectableText(
                    key,
                    style: const TextStyle(
                      color: Color(0xFF2DD4BF),
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PulsColors.amberLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: PulsColors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Copy it now — for your security it won\'t be shown again.',
                          style: TextStyle(
                              color: PulsColors.amber,
                              fontSize: 11.5,
                              height: 1.3,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Connect the Puls CLI:',
                    style: TextStyle(
                        color: t.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: t.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.border),
                  ),
                  child: Text('puls login $key',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: t.textMuted,
                          fontFamily: 'monospace',
                          fontSize: 11.5)),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: key));
                          PulsSnack.show(context, 'API key copied!');
                        },
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient:
                                LinearGradient(colors: [t.brand, PulsColors.brandMint]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 7),
                              Text('Copy key',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.border),
                        ),
                        child: Text('Done',
                            style: TextStyle(
                                color: t.text, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final ws = WalletServiceScope.of(context).state;
    if (ws.userId == null || ws.isExternalWallet) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surfaceRaised.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.terminal_rounded, color: t.brand, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('API Keys',
                        style: TextStyle(
                            color: t.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('Connect the Puls CLI & your own agents',
                        style: TextStyle(color: t.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                SizedBox(
                    width: 15,
                    height: 15,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: t.brand)),
                const SizedBox(width: 10),
                Text('Loading…', style: TextStyle(color: t.textMuted, fontSize: 12.5)),
              ]),
            )
          else if (_keys.isEmpty)
            Text(
              'No keys yet. Generate one to use the Puls CLI — chat with your agent and read live markets from your terminal.',
              style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.5),
            )
          else
            Column(
              children: [for (final k in _keys) _keyRow(t, k as Map)],
            ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _busy ? null : _generate,
            child: Container(
              width: double.infinity,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _busy
                    ? null
                    : LinearGradient(colors: [t.brand, PulsColors.brandMint]),
                color: _busy ? t.surface : null,
                borderRadius: BorderRadius.circular(12),
                border: _busy ? Border.all(color: t.border) : null,
              ),
              child: _busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: t.brand))
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('Generate API Key',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Install:  npm i -g @pulsmarket/cli   ·   then  puls login <key>',
              style: TextStyle(
                  color: t.textSubtle, fontSize: 10.5, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _keyRow(PulsThemeColors t, Map k) {
    final prefix = k['prefix'] as String? ?? 'pk_live_…';
    final label = (k['label'] as String?)?.trim();
    final lastUsed = k['lastUsedAt'];
    final id = k['id'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(Icons.vpn_key_rounded, size: 15, color: t.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$prefix…',
                    style: TextStyle(
                        color: t.text,
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(
                  '${label?.isNotEmpty == true ? label : 'Key'} · ${lastUsed != null ? 'used recently' : 'never used'}',
                  style: TextStyle(color: t.textSubtle, fontSize: 10.5),
                ),
              ],
            ),
          ),
          if (id != null)
            GestureDetector(
              onTap: () => _revoke(id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: t.noBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Revoke',
                    style: TextStyle(
                        color: t.no, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}
