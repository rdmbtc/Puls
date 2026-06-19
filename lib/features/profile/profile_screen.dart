import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/puls_snack.dart';
import '../../core/widgets/puls_page_route.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app.dart';
import '../../app/puls_app_state.dart';
import '../../core/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_sheet.dart';
import '../../core/widgets/puls_avatar.dart';
import '../../core/widgets/tactile.dart';
import '../wallet/wallet_service.dart';
import '../shell/web_layout.dart';
import '../shell/shell_nav.dart';
import '../onboarding/help_button.dart';
import '../support/support_screen.dart';
import '../portfolio/bridge_sheet.dart';
import '../portfolio/swap_sheet.dart';
import '../portfolio/funds_sheet.dart';
import '../../core/config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _displayName;
  String? _bio;
  String? _avatarUrl;
  bool _loadingProfile = false;

  /// True once we know the signed-in user has no display name set yet — used to
  /// nudge them to pick a nickname (so they don't show up nameless on the
  /// leaderboard). Hidden while the profile is still loading to avoid flicker.
  bool get _needsNickname =>
      !_loadingProfile &&
      (_displayName == null || _displayName!.trim().isEmpty);

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        setState(() {});
        _loadProfileData();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = WalletServiceScope.of(context);
      if (wallet.state.userId != null) {
        wallet.refreshBalance();
        _loadProfileData();
      }
    });
  }

  Future<void> _loadProfileData() async {
    final wallet = WalletServiceScope.of(context);
    final userId = wallet.state.userId;
    if (userId == null) return;

    if (mounted) setState(() => _loadingProfile = true);
    try {
      final data = await wallet.getUserProfile(userId);
      if (mounted) {
        setState(() {
          _displayName = data['profile']?['display_name'];
          _bio = data['profile']?['bio'];
          _avatarUrl = data['profile']?['avatar_url'];
          _loadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  void _showEditProfileDialog() {
    final wallet = WalletServiceScope.of(context);
    final ws = wallet.state;
    if (ws.userId == null) return;

    final defaultName = ws.isExternalWallet
        ? (ws.walletAddress != null && ws.walletAddress!.length > 10
            ? '${ws.walletAddress!.substring(0, 6)}...${ws.walletAddress!.substring(ws.walletAddress!.length - 4)}'
            : ws.walletAddress ?? 'Puls Trader')
        : (Supabase
                .instance.client.auth.currentUser?.userMetadata?['full_name'] ??
            Supabase.instance.client.auth.currentUser?.userMetadata?['name'] ??
            'Puls Trader') as String;

    final nameController =
        TextEditingController(text: _displayName ?? defaultName);
    final bioController = TextEditingController(text: _bio ?? '');
    final avatarController = TextEditingController(text: _avatarUrl ?? '');

    showDialog(
      context: context,
      builder: (context) {
        final t = context.puls;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: cardDecoration(t, radius: 20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Profile',
                          style: TextStyle(
                              color: t.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 16),
                        Text('DISPLAY NAME',
                            style: TextStyle(
                                color: t.textSubtle,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: nameController,
                          style: TextStyle(color: t.text, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Enter name...',
                            hintStyle: TextStyle(color: t.textMuted),
                            filled: true,
                            fillColor: t.surface,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: t.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: t.border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: t.brand)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('BIO',
                            style: TextStyle(
                                color: t.textSubtle,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: bioController,
                          style: TextStyle(color: t.text, fontSize: 14),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Tell us about yourself...',
                            hintStyle: TextStyle(color: t.textMuted),
                            filled: true,
                            fillColor: t.surface,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: t.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: t.border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: t.brand)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('AVATAR URL',
                            style: TextStyle(
                                color: t.textSubtle,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: avatarController,
                                style: TextStyle(color: t.text, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Paste image URL...',
                                  hintStyle: TextStyle(color: t.textMuted),
                                  filled: true,
                                  fillColor: t.surface,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: t.border)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: t.border)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: t.brand)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: () {
                                final rand = 'trader_' +
                                    DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString();
                                final seedType = ws.isExternalWallet
                                    ? 'identicon'
                                    : 'bottts';
                                avatarController.text =
                                    'https://api.dicebear.com/7.x/$seedType/png?seed=$rand&size=128';
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: t.brand,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.casino_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('Cancel',
                                  style: TextStyle(
                                      color: t.textSubtle,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                final snack = PulsSnack.of(context);
                                final newName = nameController.text.trim();
                                final newBio = bioController.text.trim();
                                final newAvatar = avatarController.text.trim();

                                if (newName.isEmpty) {
                                  snack.error('Name cannot be empty');
                                  return;
                                }

                                Navigator.of(context).pop();

                                snack.show('Updating profile…',
                                    duration: const Duration(seconds: 1));

                                try {
                                  await wallet.updateProfile(
                                    displayName: newName,
                                    bio: newBio,
                                    avatarUrl: newAvatar,
                                  );

                                  if (!ws.isExternalWallet) {
                                    await Supabase.instance.client.auth
                                        .updateUser(
                                      UserAttributes(
                                        data: {
                                          'full_name': newName,
                                          'avatar_url': newAvatar,
                                        },
                                      ),
                                    );
                                  }

                                  await _loadProfileData();

                                  snack
                                      .success('Profile updated successfully!');
                                } catch (e) {
                                  snack.error('Couldn\'t save — $e');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: t.brand,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Save',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final wallet = WalletServiceScope.of(context);
    final t = context.puls;
    final isDark = appState.themeMode == ThemeMode.dark;
    final ws = wallet.state;
    final supaUser = Supabase.instance.client.auth.currentUser;

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = kIsWeb && width >= 900;

    Widget body;
    if (isDesktop) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Profile Card + Wallet Control Panel
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileCard(
                      t: t,
                      supaUser: supaUser,
                      ws: ws,
                      displayName: _displayName,
                      avatarUrl: _avatarUrl,
                      onEditTap: _showEditProfileDialog,
                    ),
                    if (ws.userId != null && _needsNickname) ...[
                      const SizedBox(height: 16),
                      _NicknameReminderCard(
                          t: t, onTap: _showEditProfileDialog),
                    ],
                    const SizedBox(height: 20),
                    _WalletCard(ws: ws, wallet: wallet, t: t),
                    if (kIsWeb) ...[
                      const SizedBox(height: 20),
                      _BridgeCard(t: t, onTap: () => BridgeSheet.show(context)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Right Column: Preferences, Arc Testnet details, About L1/Circle
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Section(
                      title: 'Preferences',
                      t: t,
                      children: [
                        _Row(
                          icon: isDark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          title: 'Dark mode',
                          subtitle:
                              isDark ? 'Currently dark' : 'Currently light',
                          t: t,
                          trailing: Switch(
                            value: isDark,
                            activeTrackColor: t.brand,
                            onChanged: (_) => appState.toggleThemeMode(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _FastBuySection(appState: appState, t: t),
                    const SizedBox(height: 20),
                    _Section(
                      title: 'Arc Testnet Operations',
                      t: t,
                      children: [
                        _Row(
                          icon: Icons.water_drop_outlined,
                          title: 'Get testnet USDC',
                          subtitle: 'faucet.circle.com → Arc Testnet',
                          t: t,
                          onTap: () => launchUrl(
                            Uri.parse('https://faucet.circle.com'),
                            mode: LaunchMode.externalApplication,
                          ),
                          trailing: Icon(Icons.open_in_new_rounded,
                              size: 14, color: t.textSubtle),
                        ),
                        _Row(
                          icon: Icons.search_rounded,
                          title: 'Arc Explorer',
                          subtitle: 'testnet.arcscan.app',
                          t: t,
                          onTap: () => launchUrl(
                            Uri.parse('https://testnet.arcscan.app'),
                            mode: LaunchMode.externalApplication,
                          ),
                          trailing: Icon(Icons.open_in_new_rounded,
                              size: 14, color: t.textSubtle),
                        ),
                        _Row(
                          icon: Icons.info_outline_rounded,
                          title: 'Factory contract',
                          subtitle:
                              '${factoryAddress.substring(0, 8)}...${factoryAddress.substring(factoryAddress.length - 4)}',
                          t: t,
                          onTap: () => launchUrl(
                            Uri.parse(
                                'https://testnet.arcscan.app/address/$factoryAddress'),
                            mode: LaunchMode.externalApplication,
                          ),
                          trailing: Icon(Icons.open_in_new_rounded,
                              size: 14, color: t.textSubtle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _Section(
                      title: 'Platform Architecture',
                      t: t,
                      children: [
                        _Row(
                          icon: Icons.layers_rounded,
                          title: 'Built on Arc L1',
                          subtitle: 'USDC-native gas · L1 ecosystem',
                          t: t,
                          onTap: () => launchUrl(
                            Uri.parse('https://arc.network'),
                            mode: LaunchMode.externalApplication,
                          ),
                          trailing: Icon(Icons.open_in_new_rounded,
                              size: 14, color: t.textSubtle),
                        ),
                        _Row(
                          icon: Icons.account_balance_rounded,
                          title: 'Powered by Circle SDKs',
                          subtitle: 'Non-custodial MPC wallets · USDC rails',
                          t: t,
                          onTap: () => launchUrl(
                            Uri.parse('https://circle.com'),
                            mode: LaunchMode.externalApplication,
                          ),
                          trailing: Icon(Icons.open_in_new_rounded,
                              size: 14, color: t.textSubtle),
                        ),
                        _Row(
                          icon: Icons.show_chart_rounded,
                          title: 'Market data',
                          subtitle: 'Polymarket odds engine',
                          t: t,
                          onTap: () => launchUrl(
                            Uri.parse('https://polymarket.com'),
                            mode: LaunchMode.externalApplication,
                          ),
                          trailing: Icon(Icons.open_in_new_rounded,
                              size: 14, color: t.textSubtle),
                        ),
                        _Row(
                          icon: Icons.south_west_rounded,
                          title: 'Deposit USDC',
                          subtitle: 'Receive USDC to your Puls wallet on Arc',
                          t: t,
                          onTap: () => FundsSheet.show(context),
                          trailing: Icon(Icons.chevron_right_rounded,
                              size: 18, color: t.textSubtle),
                        ),
                        _Row(
                          icon: Icons.north_east_rounded,
                          title: 'Withdraw USDC',
                          subtitle: 'Send USDC to any Arc address',
                          t: t,
                          onTap: () => FundsSheet.show(context, withdraw: true),
                          trailing: Icon(Icons.chevron_right_rounded,
                              size: 18, color: t.textSubtle),
                        ),
                        if (kIsWeb)
                          _Row(
                            icon: Icons.swap_horiz_rounded,
                            title: 'Bridge USDC to Arc',
                            subtitle:
                                'From Ethereum, Arbitrum or Avalanche via Circle CCTP',
                            t: t,
                            onTap: () => BridgeSheet.show(context),
                            trailing: Icon(Icons.chevron_right_rounded,
                                size: 18, color: t.textSubtle),
                          ),
                        if (kIsWeb)
                          _Row(
                            icon: Icons.currency_exchange_rounded,
                            title: 'Swap USDC ↔ EURC',
                            subtitle:
                                'Stablecoin swap on Arc, powered by Circle',
                            t: t,
                            onTap: () => SwapSheet.show(context),
                            trailing: Icon(Icons.chevron_right_rounded,
                                size: 18, color: t.textSubtle),
                          ),
                        _Row(
                          icon: Icons.menu_book_rounded,
                          title: 'Documentation',
                          subtitle: 'docs.pulsmarket.tech',
                          t: t,
                          onTap: () => launchUrl(
                            Uri.parse('https://docs.pulsmarket.tech'),
                            mode: LaunchMode.externalApplication,
                          ),
                          trailing: Icon(Icons.open_in_new_rounded,
                              size: 14, color: t.textSubtle),
                        ),
                        _Row(
                          icon: Icons.support_agent_rounded,
                          title: 'Support',
                          subtitle: 'Open a ticket — we reply within a day',
                          t: t,
                          onTap: () => Navigator.of(context).push(
                            pulsRoute(context,
                                builder: (_) => const SupportScreen()),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded,
                              size: 18, color: t.textSubtle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          FadeInUp(
            delay: const Duration(milliseconds: 60),
            duration: const Duration(milliseconds: 350),
            child: _ProfileCard(
              t: t,
              supaUser: supaUser,
              ws: ws,
              displayName: _displayName,
              avatarUrl: _avatarUrl,
              onEditTap: _showEditProfileDialog,
            ),
          ),
          if (ws.userId != null && _needsNickname) ...[
            const SizedBox(height: 16),
            FadeInUp(
              delay: const Duration(milliseconds: 70),
              duration: const Duration(milliseconds: 350),
              child: _NicknameReminderCard(t: t, onTap: _showEditProfileDialog),
            ),
          ],
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 80),
            duration: const Duration(milliseconds: 350),
            child: _WalletCard(ws: ws, wallet: wallet, t: t),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 16),
            FadeInUp(
              delay: const Duration(milliseconds: 90),
              duration: const Duration(milliseconds: 350),
              child: _BridgeCard(t: t, onTap: () => BridgeSheet.show(context)),
            ),
          ],
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 350),
            child: _Section(
              title: 'Appearance',
              t: t,
              children: [
                _Row(
                  icon: isDark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  title: 'Dark mode',
                  subtitle: isDark ? 'Currently dark' : 'Currently light',
                  t: t,
                  trailing: Switch(
                    value: isDark,
                    activeTrackColor: t.brand,
                    onChanged: (_) => appState.toggleThemeMode(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 120),
            duration: const Duration(milliseconds: 350),
            child: _FastBuySection(appState: appState, t: t),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 140),
            duration: const Duration(milliseconds: 350),
            child: _Section(
              title: 'Arc Testnet',
              t: t,
              children: [
                _Row(
                  icon: Icons.water_drop_outlined,
                  title: 'Get testnet USDC',
                  subtitle: 'faucet.circle.com',
                  t: t,
                  onTap: () => launchUrl(
                    Uri.parse('https://faucet.circle.com'),
                    mode: LaunchMode.externalApplication,
                  ),
                  trailing: Icon(Icons.open_in_new_rounded,
                      size: 14, color: t.textSubtle),
                ),
                _Row(
                  icon: Icons.search_rounded,
                  title: 'Arc Explorer',
                  subtitle: 'testnet.arcscan.app',
                  t: t,
                  onTap: () => launchUrl(
                    Uri.parse('https://testnet.arcscan.app'),
                    mode: LaunchMode.externalApplication,
                  ),
                  trailing: Icon(Icons.open_in_new_rounded,
                      size: 14, color: t.textSubtle),
                ),
                _Row(
                  icon: Icons.info_outline_rounded,
                  title: 'Factory contract',
                  subtitle:
                      '${factoryAddress.substring(0, 8)}...${factoryAddress.substring(factoryAddress.length - 4)}',
                  t: t,
                  onTap: () => launchUrl(
                    Uri.parse(
                        'https://testnet.arcscan.app/address/$factoryAddress'),
                    mode: LaunchMode.externalApplication,
                  ),
                  trailing: Icon(Icons.open_in_new_rounded,
                      size: 14, color: t.textSubtle),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 160),
            duration: const Duration(milliseconds: 350),
            child: _Section(
              title: 'About',
              t: t,
              children: [
                _Row(
                  icon: Icons.layers_rounded,
                  title: 'Built on Arc',
                  subtitle: 'USDC-native gas · L1 ecosystem',
                  t: t,
                  onTap: () => launchUrl(
                    Uri.parse('https://arc.network'),
                    mode: LaunchMode.externalApplication,
                  ),
                  trailing: Icon(Icons.open_in_new_rounded,
                      size: 14, color: t.textSubtle),
                ),
                _Row(
                  icon: Icons.account_balance_rounded,
                  title: 'Powered by Circle',
                  subtitle: 'MPC wallets · USDC payments',
                  t: t,
                  onTap: () => launchUrl(
                    Uri.parse('https://circle.com'),
                    mode: LaunchMode.externalApplication,
                  ),
                  trailing: Icon(Icons.open_in_new_rounded,
                      size: 14, color: t.textSubtle),
                ),
                _Row(
                  icon: Icons.south_west_rounded,
                  title: 'Deposit USDC',
                  subtitle: 'Receive USDC to your Puls wallet on Arc',
                  t: t,
                  onTap: () => FundsSheet.show(context),
                  trailing: Icon(Icons.chevron_right_rounded,
                      size: 18, color: t.textSubtle),
                ),
                _Row(
                  icon: Icons.north_east_rounded,
                  title: 'Withdraw USDC',
                  subtitle: 'Send USDC to any Arc address',
                  t: t,
                  onTap: () => FundsSheet.show(context, withdraw: true),
                  trailing: Icon(Icons.chevron_right_rounded,
                      size: 18, color: t.textSubtle),
                ),
                if (kIsWeb)
                  _Row(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Bridge USDC to Arc',
                    subtitle:
                        'From Ethereum, Arbitrum or Avalanche via Circle CCTP',
                    t: t,
                    onTap: () => BridgeSheet.show(context),
                    trailing: Icon(Icons.chevron_right_rounded,
                        size: 18, color: t.textSubtle),
                  ),
                if (kIsWeb)
                  _Row(
                    icon: Icons.currency_exchange_rounded,
                    title: 'Swap USDC ↔ EURC',
                    subtitle: 'Stablecoin swap on Arc, powered by Circle',
                    t: t,
                    onTap: () => SwapSheet.show(context),
                    trailing: Icon(Icons.chevron_right_rounded,
                        size: 18, color: t.textSubtle),
                  ),
                _Row(
                  icon: Icons.menu_book_rounded,
                  title: 'Documentation',
                  subtitle: 'docs.pulsmarket.tech',
                  t: t,
                  onTap: () => launchUrl(
                    Uri.parse('https://docs.pulsmarket.tech'),
                    mode: LaunchMode.externalApplication,
                  ),
                  trailing: Icon(Icons.open_in_new_rounded,
                      size: 14, color: t.textSubtle),
                ),
                _Row(
                  icon: Icons.support_agent_rounded,
                  title: 'Support',
                  subtitle: 'Open a ticket — we reply within a day',
                  t: t,
                  onTap: () => Navigator.of(context).push(
                    pulsRoute(context, builder: (_) => const SupportScreen()),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded,
                      size: 18, color: t.textSubtle),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Profile Settings',
            style: TextStyle(
                color: t.text,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: const [HelpAction(tab: PulsTab.profile)],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: t.brand,
          onRefresh: wallet.refreshBalance,
          child: isDesktop ? WebLayout(maxWidth: 1200, child: body) : body,
        ),
      ),
    );
  }
}

// ── Glassmorphic card container ───────────────────────────────────────────────
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.border,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxBorder? border;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final defaultBorder = Border.all(
      color: _isHovered
          ? t.brand.withValues(alpha: 0.6)
          : t.border.withValues(alpha: 0.4),
      width: _isHovered ? 1.5 : 1.0,
    );

    Widget container = AnimatedContainer(
      duration: context.motionDuration(const Duration(milliseconds: 200)),
      curve: Curves.easeInOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: _isHovered
            ? t.surfaceRaised.withValues(alpha: 0.8)
            : t.surfaceRaised.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: widget.border ?? defaultBorder,
        gradient: widget.gradient,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899)
                .withValues(alpha: _isHovered ? 0.08 : 0.03),
            blurRadius: _isHovered ? 20 : 12,
            offset: const Offset(0, 4),
          ),
          if (_isHovered)
            BoxShadow(
              color: t.brand.withValues(alpha: 0.05),
              blurRadius: 15,
              spreadRadius: 1,
            ),
        ],
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      // Outer MouseRegion drives the hover decoration (border/glow); Tactile
      // adds the press-scale feedback + click cursor so the card feels
      // responsive on tap and pointer-aware on desktop.
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Tactile(
          onTap: widget.onTap!,
          child: container,
        ),
      );
    }
    return container;
  }
}

// ── Nickname reminder ────────────────────────────────────────────────────────
/// Shown in the profile when the signed-in user hasn't set a display name yet,
/// nudging them to pick one (tapping opens the Edit Profile dialog).
class _NicknameReminderCard extends StatelessWidget {
  const _NicknameReminderCard({required this.t, required this.onTap});

  final PulsThemeColors t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.brand.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.brand.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.brand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.badge_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set your nickname',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pick a display name so you stand out on the leaderboard.',
                      style: TextStyle(
                          color: t.textSubtle, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: t.brand,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Set',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile details ──────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.t,
    this.supaUser,
    required this.ws,
    this.displayName,
    this.avatarUrl,
    this.onEditTap,
  });
  final PulsThemeColors t;
  final dynamic supaUser;
  final WalletState ws;
  final String? displayName;
  final String? avatarUrl;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    final hasWallet = ws.userId != null;
    final defaultName = ws.isExternalWallet
        ? (ws.walletAddress != null && ws.walletAddress!.length > 10
            ? '${ws.walletAddress!.substring(0, 6)}...${ws.walletAddress!.substring(ws.walletAddress!.length - 4)}'
            : ws.walletAddress ?? 'Puls Trader')
        : (supaUser?.userMetadata?['full_name'] ??
            supaUser?.userMetadata?['name'] ??
            'Puls Trader') as String;

    final name = displayName ?? defaultName;
    final email = ws.isExternalWallet
        ? 'Connected via Web3'
        : (supaUser?.email ?? 'trader@puls.arc') as String;

    final avatar =
        avatarUrl ?? supaUser?.userMetadata?['avatar_url'] as String?;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Avatar with premium gradient border
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  t.brand,
                  PulsColors.brandMint,
                  t.brand.withValues(alpha: 0.3)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: PulsAvatar(
              url: avatar,
              name: name,
              size: 60,
              radius: 14,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(email,
                    style: TextStyle(
                        color: t.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              hasWallet
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: t.yesBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.yes.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                          ws.isExternalWallet ? 'Web3 Wallet' : 'Connected',
                          style: TextStyle(
                              color: t.yes,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: t.brandSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: t.brand.withValues(alpha: 0.2)),
                      ),
                      child: Text('DEMO MODE',
                          style: TextStyle(
                              color: t.brand,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ),
              if (hasWallet && onEditTap != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onEditTap,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(Icons.edit_rounded, size: 12, color: t.brand),
                  label: Text('Edit',
                      style: TextStyle(
                          color: t.brand,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Settings Sections ────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.t,
    required this.children,
  });
  final String title;
  final PulsThemeColors t;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 12,
                decoration: BoxDecoration(
                  color: t.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: t.textSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            separatorBuilder: (_, __) =>
                Divider(color: t.border.withValues(alpha: 0.5), height: 1),
            itemBuilder: (context, i) => children[i],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.t,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final PulsThemeColors t;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? t.surface.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _hovered ? t.brandSubtle : t.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _hovered ? t.brand.withValues(alpha: 0.3) : t.border,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: _hovered ? t.brand : t.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: t.text,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: t.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              widget.trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: widget.onTap != null
                        ? t.textSubtle
                        : Colors.transparent,
                    size: 18,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Wallet card ──────────────────────────────────────────────────────────────
/// Prominent, tappable "Bridge USDC to Arc" card for the profile.
class _BridgeCard extends StatelessWidget {
  const _BridgeCard({required this.t, required this.onTap});
  final PulsThemeColors t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              t.brand.withValues(alpha: 0.16),
              t.brand.withValues(alpha: 0.04)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.brand.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: t.brand.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.swap_horiz_rounded, color: t.brand, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bridge USDC to Arc',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('From Ethereum, Arbitrum or Avalanche · Circle CCTP',
                      style: TextStyle(color: t.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.textSubtle, size: 20),
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.ws,
    required this.wallet,
    required this.t,
  });

  final WalletState ws;
  final WalletService wallet;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    if (ws.userId == null) {
      return GlassCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [t.brand, PulsColors.brandMint],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                      child: Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 24)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Connect Your Account',
                          style: TextStyle(
                              color: t.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text('Setup a secure wallet on Arc L1',
                          style: TextStyle(
                              color: t.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Features
            _FeatureRow(
                icon: Icons.shield_outlined,
                text: 'Non-custodial MPC wallet — you own your keys',
                t: t),
            const SizedBox(height: 10),
            _FeatureRow(
                icon: Icons.flash_on_rounded,
                text: 'USDC as gas — no ETH needed',
                t: t),
            const SizedBox(height: 10),
            _FeatureRow(
                icon: Icons.speed_rounded,
                text: 'Sub-second finality on Arc Testnet',
                t: t),
            const SizedBox(height: 28),
            // Google button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: ws.isLoading ? null : wallet.signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: ws.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, size: 20),
                          SizedBox(width: 10),
                          Text('Connect with Google',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      ),
              ),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: ws.isLoading
                      ? null
                      : () async {
                          try {
                            await wallet.signInWithExternalWallet();
                          } catch (e) {
                            if (context.mounted) {
                              PulsSnack.error(context, 'Connection failed: $e');
                            }
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.text,
                    side: BorderSide(color: t.border, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: ws.isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: t.brand))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 20, color: t.text),
                            const SizedBox(width: 10),
                            Text('Connect Web3 Wallet',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: t.text)),
                          ],
                        ),
                ),
              ),
            ],
            if (ws.error != null) ...[
              const SizedBox(height: 14),
              Text(ws.error!,
                  style: TextStyle(
                      color: t.no, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [t.brand, PulsColors.brandMint],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ws.isExternalWallet
                          ? 'Web3 Wallet (MetaMask)'
                          : 'Arc Testnet Wallet',
                      style: TextStyle(
                          color: t.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: -0.3),
                    ),
                    if (ws.walletAddress != null &&
                        ws.walletAddress!.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: ws.walletAddress!));
                          PulsSnack.show(context, 'Address copied to clipboard',
                              duration: const Duration(seconds: 2));
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${ws.walletAddress!.substring(0, 6)}...${ws.walletAddress!.substring(ws.walletAddress!.length - 4)}',
                              style: TextStyle(
                                  color: t.textMuted,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.copy_rounded,
                                size: 12, color: t.textSubtle),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.border),
                ),
                child: IconButton(
                  onPressed: ws.isLoading ? null : wallet.refreshBalance,
                  icon: ws.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.refresh_rounded,
                          color: t.textMuted, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('USDC Balance',
                      style: TextStyle(
                          color: t.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${double.tryParse(ws.usdcBalance)?.toStringAsFixed(2) ?? ws.usdcBalance}',
                        style: TextStyle(
                            color: t.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                            letterSpacing: -1.0),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'USDC',
                        style: TextStyle(
                            color: t.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: t.yesBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.yes.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: t.yes),
                    const SizedBox(width: 6),
                    Text(
                      'Arc L1 Testnet',
                      style: TextStyle(
                          color: t.yes,
                          fontSize: 10,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (ws.walletAddress != null && ws.walletAddress!.isNotEmpty) ...[
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: ws.walletAddress!));
                PulsSnack.show(context, 'Address copied to clipboard',
                    duration: const Duration(seconds: 2));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border.withValues(alpha: 0.8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ws.walletAddress!,
                        style: TextStyle(
                            color: t.textMuted,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.copy_rounded, size: 14, color: t.brand),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if ((double.tryParse(ws.usdcBalance) ?? 0) == 0)
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://faucet.circle.com'),
                  mode: LaunchMode.externalApplication),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PulsColors.amberLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: PulsColors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop_rounded,
                        size: 18, color: PulsColors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                              color: PulsColors.amber,
                              fontSize: 12,
                              height: 1.4),
                          children: [
                            TextSpan(
                                text:
                                    'Wallet empty. Get free gas + testnet USDC from ',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            TextSpan(
                              text: 'faucet.circle.com',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.underline,
                                  color: Colors.amber),
                            ),
                            TextSpan(text: ' →'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: t.textSubtle),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Top up gas / USDC anytime at faucet.circle.com (select Arc Testnet network)',
                      style: TextStyle(
                          color: t.textSubtle,
                          fontSize: 11,
                          height: 1.4,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _showWalletInfo(context, ws, wallet, t),
                icon: Icon(Icons.analytics_outlined, size: 14, color: t.brand),
                label: Text('Diagnostic Info',
                    style: TextStyle(
                        color: t.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: t.brandSubtle,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: wallet.signOut,
                icon: Icon(Icons.logout_rounded, size: 14, color: t.no),
                label: Text('Disconnect',
                    style: TextStyle(
                        color: t.no,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: t.noBg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWalletInfo(BuildContext context, WalletState ws, WalletService wallet, PulsThemeColors t) {
    PulsSheet.show(
      context,
      builder: (_) => PulsSheetSurface(
        raised: true,
        scrollable: true,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Technical Details', style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _InfoRow('Target Network', 'Arc Testnet L1', t),
            _InfoRow('Chain ID', '5042002', t),
            _InfoRow('Gas Fee Asset', 'USDC (Native gas)', t),
            _InfoRow(
                'Provider type',
                ws.isExternalWallet
                    ? 'External Web3 Wallet (MetaMask)'
                    : 'Circle Programmable Wallet (MPC)',
                t),
            if (ws.walletAddress != null) ...[
              const SizedBox(height: 12),
              Text('Full Wallet Hex Address',
                  style: TextStyle(color: t.textMuted, fontSize: 12)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: ws.walletAddress!));
                  final snack = PulsSnack.of(context);
                  Navigator.pop(context);
                  snack.show('Address copied!');
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(ws.walletAddress!,
                            style: TextStyle(
                                color: t.text,
                                fontSize: 12,
                                fontFamily: 'monospace')),
                      ),
                      Icon(Icons.copy_rounded, size: 16, color: t.brand),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Done',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, this.t);
  final String label;
  final String value;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: t.textMuted, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: t.text, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Feature row helper ────────────────────────────────────────────────────────
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text, required this.t});
  final IconData icon;
  final String text;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: t.brand),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style:
                    TextStyle(color: t.textMuted, fontSize: 14, height: 1.3))),
      ],
    );
  }
}

// ── Fast buy console ──────────────────────────────────────────────────────────
class _FastBuySection extends StatelessWidget {
  const _FastBuySection({required this.appState, required this.t});
  final PulsAppState appState;
  final PulsThemeColors t;

  static const _amounts = [0.5, 1.0, 2.0, 5.0, 10.0];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      border: Border.all(
        color: appState.fastBuyEnabled
            ? t.brand.withValues(alpha: 0.5)
            : t.border.withValues(alpha: 0.4),
        width: appState.fastBuyEnabled ? 1.5 : 1.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: appState.fastBuyEnabled ? t.brand : t.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.border),
                  boxShadow: appState.fastBuyEnabled
                      ? [
                          BoxShadow(
                            color: t.brand.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: appState.fastBuyEnabled ? Colors.white : t.textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fast Buy Console',
                        style: TextStyle(
                            color: t.text,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      appState.fastBuyEnabled
                          ? 'Swipe to trade instantly · \$${appState.fastBuyAmount.toStringAsFixed(appState.fastBuyAmount % 1 == 0 ? 0 : 1)} USDC'
                          : 'Skip confirmations & trade with swipe actions',
                      style: TextStyle(
                          color: t.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Switch(
                value: appState.fastBuyEnabled,
                activeTrackColor: t.brand,
                onChanged: (_) => appState.toggleFastBuy(),
              ),
            ],
          ),
          if (appState.fastBuyEnabled) ...[
            const SizedBox(height: 18),
            Text('Auto-buy Amount limit',
                style: TextStyle(
                    color: t.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Row(
              children: _amounts.map((amt) {
                final selected = appState.fastBuyAmount == amt;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => appState.setFastBuyAmount(amt),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? t.brand : t.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? t.brand : t.border,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: t.brand.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        '\$${amt.toStringAsFixed(amt % 1 == 0 ? 0 : 1)}',
                        style: TextStyle(
                          color: selected ? Colors.white : t.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.brandSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.brand.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.swipe_rounded, color: t.brand, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Swipe Right = Buy YES · Swipe Left = Buy NO (Instantly executes)',
                      style: TextStyle(
                          color: t.brand,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
