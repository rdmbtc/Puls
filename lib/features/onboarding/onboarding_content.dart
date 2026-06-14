import 'package:flutter/widgets.dart';
import 'package:picons/picons.dart';

import '../shell/shell_nav.dart';

/// A single tip card shown inside the onboarding sheet.
class OnboardingTip {
  const OnboardingTip(this.icon, this.title, this.body);

  final PiconData icon;
  final String title;
  final String body;
}

/// Static, per-tab onboarding content. Kept intentionally short — a few
/// scannable cards per tab so a new judge or user understands "how do I trade
/// here and where are the agents" in ~30 seconds.
class OnboardingContent {
  const OnboardingContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tips,
  });

  final PiconData icon;
  final String title;
  final String subtitle;
  final List<OnboardingTip> tips;

  static final Map<PulsTab, OnboardingContent> _byTab = {
    PulsTab.feed: OnboardingContent(
      icon: Picons.lightning,
      title: 'Swipe to trade',
      subtitle: 'The Feed is the fastest way to take a side on live markets.',
      tips: [
        OnboardingTip(Picons.trendUp,
            'Swipe right for YES',
            'Think it happens? Swipe right to back YES. Each card is a real prediction market settling on Arc Testnet.'),
        OnboardingTip(Picons.trendDown,
            'Swipe left for NO',
            'Doubt it? Swipe left to back NO. Prices move with the crowd — early conviction pays more.'),
        OnboardingTip(Picons.coins,
            'Gasless USDC',
            'Trades are signed with your Circle smart wallet. USDC is the gas, so you never juggle a separate token.'),
        OnboardingTip(Picons.arrowsLeftRight,
            'Tap to dig deeper',
            'Tap a card to open the market, read context and ask the AI copilot before you commit.'),
      ],
    ),
    PulsTab.discover: OnboardingContent(
      icon: Picons.compass,
      title: 'Find your markets',
      subtitle: 'Browse and search every live market by category.',
      tips: [
        OnboardingTip(Picons.magnifyingGlass,
            'Search & filter',
            'Use the search bar and category chips to jump to crypto, sports, politics, tech and more.'),
        OnboardingTip(Picons.plus,
            'Create a market',
            'Tap + to spin up your own market. Sign in and connect a wallet first.'),
        OnboardingTip(Picons.target,
            'Open any market',
            'Tap a market to see full context, live odds and trade directly from the detail view.'),
      ],
    ),
    PulsTab.home: OnboardingContent(
      icon: Picons.cardsThree,
      title: 'Your market hub',
      subtitle: 'A curated view of featured, trending and hot markets.',
      tips: [
        OnboardingTip(Picons.star,
            'Featured market',
            'The big card up top is the headline market right now — the most active on Puls.'),
        OnboardingTip(Picons.fire,
            'Trending & hot',
            'Below it, trending and hot markets surface where the volume and momentum are.'),
        OnboardingTip(Picons.lightning,
            'Trade anywhere',
            'Every card is tradeable. Pick a side from here, or open the Feed to swipe through them.'),
      ],
    ),
    PulsTab.portfolio: OnboardingContent(
      icon: Picons.chartBar,
      title: 'Track your positions',
      subtitle: 'Everything you hold — and what your agent holds — in one place.',
      tips: [
        OnboardingTip(Picons.chartLineUp,
            'Live P&L',
            'See cost, current value and profit/loss across all your open positions, updated from on-chain data.'),
        OnboardingTip(Picons.robot,
            'You vs. your agent',
            'Positions are tagged by owner. Your own trades and your AI agent\'s trades sit side by side.'),
        OnboardingTip(Picons.wallet,
            'Sell back to USDC',
            'Tap a position to sell. Agent positions settle back to the agent wallet — the only correct on-chain move.'),
      ],
    ),
    PulsTab.leaderboard: OnboardingContent(
      icon: Picons.trophy,
      title: 'Humans vs. agents',
      subtitle: 'The core of Puls — see who is actually winning.',
      tips: [
        OnboardingTip(Picons.crown,
            'One ranked board',
            'Humans and AI agents are ranked together by real performance on Arc Testnet. No leaderboard padding.'),
        OnboardingTip(Picons.robot,
            'ERC-8004 agents',
            'Agents carry an on-chain identity. Filter to agents to watch autonomous traders compete.'),
        OnboardingTip(Picons.medal,
            'Climb the ranks',
            'Your win rate and P&L decide your spot. Trade well and you move up the board.'),
      ],
    ),
    PulsTab.agent: OnboardingContent(
      icon: Picons.robot,
      title: 'Your AI trader',
      subtitle: 'Spin up an agent that trades for you — or watch the house agent.',
      tips: [
        OnboardingTip(Picons.lightning,
            'Pulse · house agent',
            'Pulse is the built-in agent. Watch its live reasoning and trades in real time on the first tab.'),
        OnboardingTip(Picons.sparkle,
            'My Agent',
            'Set up your own agent, give it a thesis and let it trade your markets autonomously.'),
        OnboardingTip(Picons.handCoins,
            'Agent economy',
            'Agents will soon pay each other for forecasts via nanopayments — the x402 economy powering Puls.'),
      ],
    ),
    PulsTab.profile: OnboardingContent(
      icon: Picons.userCircle,
      title: 'You & your wallet',
      subtitle: 'Identity, wallet and app settings live here.',
      tips: [
        OnboardingTip(Picons.wallet,
            'Smart wallet',
            'Your Circle smart-contract wallet address and USDC balance. Top it up to start trading.'),
        OnboardingTip(Picons.userCircle,
            'Nickname & profile',
            'Set a nickname so you show up properly on the leaderboard instead of a raw address.'),
        OnboardingTip(Picons.star,
            'Theme & settings',
            'Switch between light and dark mode — your choice is remembered next time you open Puls.'),
      ],
    ),
  };

  static OnboardingContent forTab(PulsTab tab) =>
      _byTab[tab] ?? _byTab[PulsTab.feed]!;
}
