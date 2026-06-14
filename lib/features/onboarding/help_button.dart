import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../shell/shell_nav.dart';
import 'onboarding_flags.dart';
import 'onboarding_sheet.dart';

/// A small circular "?" button placed in each tab's header. Tapping it opens
/// the onboarding tip sheet for that tab. Until a user has opened the tips for
/// a tab at least once, a subtle pulsing dot draws attention to it.
class HelpButton extends StatefulWidget {
  const HelpButton({required this.tab, this.size = 36, super.key});

  final PulsTab tab;
  final double size;

  @override
  State<HelpButton> createState() => _HelpButtonState();
}

class _HelpButtonState extends State<HelpButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _seen = false;

  @override
  void initState() {
    super.initState();
    _seen = OnboardingFlags.tabSeen(widget.tab);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    await OnboardingSheet.show(context, widget.tab);
    if (mounted) setState(() => _seen = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return GestureDetector(
      onTap: _open,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: widget.size + 6,
          height: widget.size + 6,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: t.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.border),
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  color: t.textSubtle,
                  size: widget.size * 0.5,
                ),
              ),
              if (!_seen)
                Positioned(
                  top: 2,
                  right: 2,
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.45, end: 1.0)
                        .animate(_pulse),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: t.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.surface, width: 1.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An [AppBar]-friendly variant with sensible padding for use in `actions:`.
class HelpAction extends StatelessWidget {
  const HelpAction({required this.tab, super.key});

  final PulsTab tab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(child: HelpButton(tab: tab)),
    );
  }
}
