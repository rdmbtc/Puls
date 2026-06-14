import '../../core/utils/kv_store.dart';
import '../shell/shell_nav.dart';

/// Persistent "seen" flags for the onboarding system. Backed by the same tiny
/// cross-platform KV store used for the theme preference — on web this is
/// localStorage, so flags survive a page reload at zero cost.
class OnboardingFlags {
  OnboardingFlags._();

  static const _welcomeKey = 'onb_welcome_seen_v1';
  static String _tabKey(PulsTab tab) => 'onb_tab_seen_v1_${tab.name}';

  /// Whether the one-time welcome sheet has been shown on this device.
  static bool get welcomeSeen => kvGet(_welcomeKey) == '1';
  static void markWelcomeSeen() => kvSet(_welcomeKey, '1');

  /// Whether the user has opened the help/tips for a given tab before. Drives
  /// the small "new" pulse dot on the help button.
  static bool tabSeen(PulsTab tab) => kvGet(_tabKey(tab)) == '1';
  static void markTabSeen(PulsTab tab) => kvSet(_tabKey(tab), '1');
}
