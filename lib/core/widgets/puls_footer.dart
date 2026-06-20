import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme/app_theme.dart';
import '../motion.dart';

/// Slim, premium footer bar for the desktop web app shell.
///
/// Designed for in-app use (not a fat marketing footer): one compact strip with
/// brand + legal/resource links + a "Verified on Arc" badge that deep-links the
/// live contract on the Arc explorer. Token-driven, so it follows light/dark.
class PulsFooter extends StatelessWidget {
  const PulsFooter({super.key});

  static const _explorerAddress =
      'https://testnet.arcscan.app/address/$factoryAddress';

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 760;
            final brand = _Brand(t: t);
            final links = _LinkRow(t: t);
            final badge = _ArcBadge(t: t, url: _explorerAddress);
            const status = _LiveStatus();

            if (wide) {
              return Row(
                children: [
                  brand,
                  const SizedBox(width: 14),
                  status,
                  const Spacer(),
                  Flexible(child: links),
                  const SizedBox(width: 20),
                  badge,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    brand,
                    const Spacer(),
                    badge,
                  ],
                ),
                const SizedBox(height: 12),
                status,
                const SizedBox(height: 12),
                links,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.t});
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: t.brandSubtle,
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/logo.png', fit: BoxFit.cover),
        ),
        const SizedBox(width: 9),
        Text(
          'Puls',
          style: TextStyle(
            fontFamily: PulsColors.fontDisplay,
            color: t.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '© 2026',
          style: TextStyle(
            color: t.textSubtle,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.t});
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: const [
        _FooterLink('Docs', 'https://docs.pulsmarket.tech'),
        _FooterLink('GitHub', 'https://github.com/rdmbtc/Puls'),
        _FooterLink('Explorer', PulsFooter._explorerAddress),
        _FooterLink('Terms', '$appBaseUrl/terms'),
        _FooterLink('Privacy', '$appBaseUrl/privacy'),
        _FooterLink('Disclaimer', '$appBaseUrl/disclaimer'),
      ],
    );
  }
}

class _FooterLink extends StatefulWidget {
  const _FooterLink(this.label, this.url);
  final String label;
  final String url;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse(widget.url),
          mode: LaunchMode.externalApplication,
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: _hovered ? t.text : t.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            decoration:
                _hovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: t.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ArcBadge extends StatefulWidget {
  const _ArcBadge({required this.t, required this.url});
  final PulsThemeColors t;
  final String url;

  @override
  State<_ArcBadge> createState() => _ArcBadgeState();
}

class _ArcBadgeState extends State<_ArcBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse(widget.url),
          mode: LaunchMode.externalApplication,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _hovered ? t.borderStrong : t.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: t.yes,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'Verified on Arc',
                style: TextStyle(
                  color: t.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Live status pill for the footer — polls /api/live and shows a pulsing dot
/// + the running trade count. Taps through to the live Puls Explorer.
class _LiveStatus extends StatefulWidget {
  const _LiveStatus();

  @override
  State<_LiveStatus> createState() => _LiveStatusState();
}

class _LiveStatusState extends State<_LiveStatus> {
  Timer? _timer;
  int? _trades;
  bool _online = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _poll();
    // Footer is persistent; 4s keeps it "live" without hammering the backend.
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/live'))
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _trades = (data['trades'] as num?)?.toInt();
          _online = true;
        });
      } else {
        setState(() => _online = false);
      }
    } catch (_) {
      if (mounted) setState(() => _online = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final color = _online ? t.yes : t.textSubtle;
    final label = _online
        ? (_trades != null ? '$_trades trades · live' : 'Live')
        : 'reconnecting…';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('$appBaseUrl/explorer'),
          mode: LaunchMode.externalApplication,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _hovered ? t.borderStrong : t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulseDot(color: color, animate: _online),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: t.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small dot that gently pulses while live.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.animate});
  final Color color;
  final bool animate;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honor reduce-motion (and the parent's animate flag): hold the dot still.
    if (widget.animate && !context.reduceMotion) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || context.reduceMotion) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        return SizedBox(
          width: 8,
          height: 8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - v) * 0.5,
                child: Container(
                  width: 8 + v * 8,
                  height: 8 + v * 8,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
