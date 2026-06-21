import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme/app_theme.dart';
import 'landing_kit.dart';

/// "Your first trade in a swipe" — an auto-playing phone mockup that swipes
/// markets YES/NO and shows the sub-second on-chain settle. Fully self-contained
/// (no backend) and reduce-motion aware (holds a still card).
class PhoneDemoSection extends StatelessWidget {
  const PhoneDemoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 880;

    final copy = _Copy(isMobile: isMobile);
    const phone = Center(child: _PhoneMock());

    return Container(
      color: t.surface.withValues(alpha: 0.35),
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 52 : 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: isMobile
              ? Column(children: [copy, const SizedBox(height: 44), phone])
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: copy),
                    const SizedBox(width: 48),
                    const Expanded(flex: 5, child: phone),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Copy extends StatelessWidget {
  const _Copy({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final cross = isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final align = isMobile ? TextAlign.center : TextAlign.left;
    return Column(
      crossAxisAlignment: cross,
      children: [
        const LandingEyebrow(label: 'MOBILE-FIRST', icon: Icons.swipe_rounded),
        const SizedBox(height: 20),
        // Headline (left-aligned variant)
        Column(
          crossAxisAlignment: cross,
          children: [
            Text('Your first trade',
                textAlign: align,
                style: TextStyle(
                    fontFamily: PulsColors.fontDisplay,
                    color: t.text,
                    fontSize: isMobile ? 30 : 46,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    letterSpacing: -1.3)),
            AnimatedGradientText('in a single swipe.',
                textAlign: align,
                style: TextStyle(
                    fontFamily: PulsColors.fontDisplay,
                    fontSize: isMobile ? 30 : 46,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    height: 1.12,
                    letterSpacing: -1.3)),
          ],
        ),
        const SizedBox(height: 22),
        _bullet(t, Icons.swipe_right_rounded, t.yes, 'Swipe right for YES, left for NO',
            'No order forms, no confirmation modal — just a flick.', align, isMobile),
        _bullet(t, Icons.bolt_rounded, t.brand, 'Settled on Arc in under a second',
            'Sub-second finality means it feels instant.', align, isMobile),
        _bullet(t, Icons.account_balance_wallet_rounded, const Color(0xFF0EA5E9),
            'USDC is the gas token', 'No ETH, no seed phrase, no bridging — ever.', align, isMobile),
      ],
    );
  }

  Widget _bullet(PulsThemeColors t, IconData icon, Color c, String title, String body,
      TextAlign align, bool isMobile) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: c),
        ),
        const SizedBox(width: 13),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: t.text, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(body,
                  style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.5)),
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: isMobile
          ? ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: row)
          : row,
    );
  }
}

class _DemoMarket {
  const _DemoMarket(this.question, this.yes);
  final String question;
  final int yes; // YES cents
}

class _PhoneMock extends StatefulWidget {
  const _PhoneMock();

  @override
  State<_PhoneMock> createState() => _PhoneMockState();
}

class _PhoneMockState extends State<_PhoneMock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const _markets = [
    _DemoMarket('Will Bitcoin close above \$100k this year?', 63),
    _DemoMarket('Fed cuts rates at the next meeting?', 41),
    _DemoMarket('An English club wins the Champions League?', 55),
    _DemoMarket('Will SpaceX reach orbit again this quarter?', 78),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final scale = w < 420 ? 0.84 : 1.0;
    final pw = 300.0 * scale;
    final ph = 600.0 * scale;

    return SizedBox(
      width: pw,
      height: ph,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = reduce ? 0.18 : _c.value;
          // Each market gets a 1/N slice of the loop.
          final slice = 1.0 / _markets.length;
          final idx = (v / slice).floor().clamp(0, _markets.length - 1);
          final localT = ((v - idx * slice) / slice).clamp(0.0, 1.0);
          final yes = idx.isEven; // alternate YES / NO
          final progress = Curves.easeIn.transform((localT / 0.55).clamp(0.0, 1.0));
          final dir = yes ? 1.0 : -1.0;
          final dx = reduce ? 0.0 : dir * progress * (pw * 0.9);
          final rot = reduce ? 0.0 : dir * progress * 0.22;
          final stamp = reduce ? 0.0 : ((progress - 0.15) / 0.3).clamp(0.0, 1.0);
          final settled = !reduce && localT > 0.6 && localT < 0.96;
          final next = (idx + 1) % _markets.length;

          return _frame(
            t,
            scale: scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Next card peeking behind.
                Transform.translate(
                  offset: Offset(0, 14 * scale),
                  child: Transform.scale(
                    scale: 0.94,
                    child: Opacity(
                        opacity: 0.5, child: _card(t, _markets[next], scale, ghost: true)),
                  ),
                ),
                // Active card.
                Transform.translate(
                  offset: Offset(dx, 0),
                  child: Transform.rotate(
                    angle: rot,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        _card(t, _markets[idx], scale, ghost: false),
                        Positioned(
                          top: 22 * scale,
                          child: Opacity(
                            opacity: stamp,
                            child: Transform.rotate(
                              angle: -0.24,
                              child: _stampBadge(yes ? t.yes : t.no, yes ? 'YES' : 'NO', scale),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Settle confirmation toast.
                Positioned(
                  bottom: 70 * scale,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 260),
                    offset: settled ? Offset.zero : const Offset(0, 0.6),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 260),
                      opacity: settled ? 1 : 0,
                      child: _settleToast(t, yes, scale),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _frame(PulsThemeColors t, {required Widget child, required double scale}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(42 * scale),
        border: Border.all(color: const Color(0xFF222B40), width: 7 * scale),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 50,
              offset: const Offset(0, 30)),
          BoxShadow(
              color: t.brand.withValues(alpha: 0.12),
              blurRadius: 60,
              spreadRadius: -10),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36 * scale),
        child: Container(
          color: t.bg,
          child: Stack(
            children: [
              // App chrome
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _appBar(t, scale),
              ),
              Positioned.fill(
                top: 64 * scale,
                bottom: 54 * scale,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18 * scale),
                  child: child,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _hintBar(t, scale),
              ),
              // Notch
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: EdgeInsets.only(top: 8 * scale),
                  width: 90 * scale,
                  height: 18 * scale,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E1A),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appBar(PulsThemeColors t, double scale) => Container(
        padding: EdgeInsets.fromLTRB(18 * scale, 30 * scale, 18 * scale, 8 * scale),
        child: Row(
          children: [
            Container(
              width: 22 * scale,
              height: 22 * scale,
              decoration: BoxDecoration(
                  gradient: PulsColors.pulseGradient,
                  borderRadius: BorderRadius.circular(7 * scale)),
            ),
            SizedBox(width: 8 * scale),
            Text('Puls',
                style: TextStyle(
                    fontFamily: PulsColors.fontDisplay,
                    color: t.text,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9 * scale, vertical: 4 * scale),
              decoration: BoxDecoration(
                  color: t.yesBg, borderRadius: BorderRadius.circular(100)),
              child: Text('\$50.00',
                  style: TextStyle(
                      color: t.yes,
                      fontSize: 11 * scale,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

  Widget _hintBar(PulsThemeColors t, double scale) => Container(
        padding: EdgeInsets.symmetric(vertical: 16 * scale),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_back_rounded, size: 14 * scale, color: t.no),
            SizedBox(width: 5 * scale),
            Text('NO',
                style: TextStyle(color: t.no, fontSize: 11 * scale, fontWeight: FontWeight.w800)),
            SizedBox(width: 16 * scale),
            Text('swipe',
                style: TextStyle(color: t.textSubtle, fontSize: 11 * scale)),
            SizedBox(width: 16 * scale),
            Text('YES',
                style: TextStyle(color: t.yes, fontSize: 11 * scale, fontWeight: FontWeight.w800)),
            SizedBox(width: 5 * scale),
            Icon(Icons.arrow_forward_rounded, size: 14 * scale, color: t.yes),
          ],
        ),
      );

  Widget _card(PulsThemeColors t, _DemoMarket m, double scale, {required bool ghost}) {
    return Container(
      width: 230 * scale,
      padding: EdgeInsets.all(18 * scale),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(22 * scale),
        border: Border.all(color: ghost ? t.border : t.brand.withValues(alpha: 0.35)),
        boxShadow: ghost
            ? []
            : [
                BoxShadow(
                    color: t.brand.withValues(alpha: 0.16),
                    blurRadius: 30,
                    offset: const Offset(0, 14)),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7 * scale,
                height: 7 * scale,
                decoration: BoxDecoration(color: t.yes, shape: BoxShape.circle),
              ),
              SizedBox(width: 5 * scale),
              Text('LIVE',
                  style: TextStyle(
                      color: t.yes,
                      fontSize: 9 * scale,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8)),
            ],
          ),
          SizedBox(height: 12 * scale),
          Text(m.question,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: t.text,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w700,
                  height: 1.3)),
          SizedBox(height: 16 * scale),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${m.yes}¢',
                  style: TextStyle(
                      fontFamily: PulsColors.fontDisplay,
                      color: t.brand,
                      fontSize: 34 * scale,
                      fontWeight: FontWeight.w700,
                      height: 1)),
              SizedBox(width: 6 * scale),
              Padding(
                padding: EdgeInsets.only(bottom: 4 * scale),
                child: Text('chance YES',
                    style: TextStyle(color: t.textSubtle, fontSize: 11 * scale)),
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              height: 7 * scale,
              child: Row(
                children: [
                  Expanded(flex: m.yes, child: Container(color: t.yes)),
                  Expanded(
                      flex: 100 - m.yes,
                      child: Container(color: t.no.withValues(alpha: 0.65))),
                ],
              ),
            ),
          ),
          SizedBox(height: 10 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('YES ${m.yes}¢',
                  style: TextStyle(
                      color: t.yes, fontSize: 11 * scale, fontWeight: FontWeight.w700)),
              Text('NO ${100 - m.yes}¢',
                  style: TextStyle(
                      color: t.no, fontSize: 11 * scale, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stampBadge(Color c, String label, double scale) => Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 7 * scale),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: c, width: 2.5 * scale),
        ),
        child: Text(label,
            style: TextStyle(
                color: c,
                fontSize: 20 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: 2)),
      );

  Widget _settleToast(PulsThemeColors t, bool yes, double scale) => Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 10 * scale),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: t.yes.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 16 * scale, color: t.yes),
            SizedBox(width: 7 * scale),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Settled in 0.42s on Arc',
                    style: TextStyle(
                        color: t.text,
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w800)),
                Text('${yes ? 'YES' : 'NO'} · paid in USDC gas',
                    style: TextStyle(color: t.textMuted, fontSize: 10.5 * scale)),
              ],
            ),
          ],
        ),
      );
}
