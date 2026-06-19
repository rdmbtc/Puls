import 'package:flutter/material.dart';
import '../../core/widgets/puls_snack.dart';

import '../../app/puls_app.dart';
import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_sheet.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';
import '../wallet/tx_status_sheet.dart';

Future<void> showTradePreviewSheet({
  required BuildContext context,
  required Market market,
  required MarketSide side,
  bool initialIsBuy = true,
  double? maxShares,
  String owner = 'user',
}) {
  return PulsSheet.show<void>(
    context,
    builder: (_) => TradePreviewSheet(
      market: market,
      side: side,
      initialIsBuy: initialIsBuy,
      maxShares: maxShares,
      owner: owner,
    ),
  );
}

class TradePreviewSheet extends StatefulWidget {
  const TradePreviewSheet({
    required this.market,
    required this.side,
    this.initialIsBuy = true,
    this.maxShares,
    this.owner = 'user',
    super.key,
  });

  final Market market;
  final MarketSide side;
  final bool initialIsBuy;
  final double? maxShares;
  // Which wallet holds the position being sold: 'user' or 'agent'.
  final String owner;

  @override
  State<TradePreviewSheet> createState() => _TradePreviewSheetState();
}

class _TradePreviewSheetState extends State<TradePreviewSheet> {
  late final TextEditingController _ctrl;
  late bool _isBuy;
  double _amount = 50;
  bool _isExecuting = false;

  String _formatShares(double shares) {
    final microShares = (shares * 1000000).floor();
    final value = microShares / 1000000;
    String str = value.toStringAsFixed(6);
    while (str.contains('.') && (str.endsWith('0') || str.endsWith('.'))) {
      if (str.endsWith('.')) {
        str = str.substring(0, str.length - 1);
        break;
      }
      str = str.substring(0, str.length - 1);
    }
    return str;
  }
  bool _isLimit = false;
  double _limitPrice = 0.5;
  late final TextEditingController _limitPriceCtrl;

  @override
  void initState() {
    super.initState();
    _isBuy = widget.initialIsBuy;
    _amount = _isBuy ? 50.0 : (widget.maxShares ?? 10.0);
    _ctrl = TextEditingController(text: _isBuy ? _amount.toStringAsFixed(0) : _formatShares(_amount));
    
    final initialPrice = widget.side == MarketSide.yes ? widget.market.yesPrice : widget.market.noPrice;
    _limitPrice = initialPrice;
    _limitPriceCtrl = TextEditingController(text: _limitPrice.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _limitPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final walletService = WalletServiceScope.of(context);
    final ws = walletService.state;
    final t = context.puls;
    final isYes = widget.side == MarketSide.yes;
    final sideBg = isYes ? t.yesBg : t.noBg;
    final sideFg = isYes ? t.yes : t.no;
    final sideLabel = isYes ? 'YES' : 'NO';
    
    // Dynamic price calculation
    final price = _isLimit ? _limitPrice : (isYes ? widget.market.yesPrice : widget.market.noPrice);
    final estShares = _isBuy ? (price > 0 ? _amount / price : 0.0) : _amount;
    final estPayout = _isBuy ? estShares : (_amount * price);
    final profit = _isBuy ? (estPayout - _amount) : 0.0;
    
    final hasRealWallet = ws.userId != null && ws.hasWallet;

    return PulsSheetSurface(
      raised: true,
      scrollable: true,
      child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BUY/SELL Tabs
              Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.border),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isBuy = true;
                          _amount = 50.0;
                          _ctrl.text = '50';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isBuy ? t.surfaceRaised : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _isBuy 
                                ? [BoxShadow(color: const Color(0xFFEC4899).withValues(alpha: 0.05), blurRadius: 2)] 
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'BUY',
                              style: TextStyle(
                                color: _isBuy ? t.text : t.textMuted,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isBuy = false;
                          _amount = widget.maxShares ?? 10.0;
                          _ctrl.text = _formatShares(_amount);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isBuy ? t.surfaceRaised : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: !_isBuy 
                                ? [BoxShadow(color: const Color(0xFFEC4899).withValues(alpha: 0.05), blurRadius: 2)] 
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'SELL',
                              style: TextStyle(
                                color: !_isBuy ? t.text : t.textMuted,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              
              // Order Type Tabs: MARKET vs LIMIT
              Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.border),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isLimit = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: !_isLimit ? t.surfaceRaised : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Market Order',
                              style: TextStyle(
                                color: !_isLimit ? t.text : t.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final wallet = WalletServiceScope.of(context).state;
                          final supportsLimit = wallet.userId != null && wallet.hasWallet && !wallet.isExternalWallet;
                          if (!supportsLimit) {
                            PulsSnack.error(context,
                                'Limit orders are only available with email-authenticated Puls custodial wallets.');
                          } else {
                            setState(() => _isLimit = true);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: _isLimit ? t.surfaceRaised : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Limit Order 🎯',
                              style: TextStyle(
                                color: _isLimit ? t.text : t.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sideBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(sideLabel,
                        style: TextStyle(
                            color: sideFg,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isBuy ? 'Buy Prediction Shares' : 'Sell Prediction Shares',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.market.question,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: t.text),
                decoration: InputDecoration(
                  labelText: _isBuy ? 'Amount (USDC)' : 'Shares to Sell',
                  labelStyle: TextStyle(color: t.textMuted),
                  prefixText: _isBuy ? '\$' : '',
                  prefixStyle: TextStyle(color: t.text),
                ),
                onChanged: (v) =>
                    setState(() => _amount = double.tryParse(v) ?? 0),
              ),
              if (_isLimit) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _limitPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: t.text),
                  decoration: InputDecoration(
                    labelText: 'Limit Price (USDC per share)',
                    labelStyle: TextStyle(color: t.textMuted),
                    prefixText: '\$',
                    prefixStyle: TextStyle(color: t.text),
                    hintText: 'e.g. 0.45',
                  ),
                  onChanged: (v) =>
                      setState(() => _limitPrice = double.tryParse(v) ?? 0.5),
                ),
              ],
              const SizedBox(height: 12),
              
              // Quick action buttons
              Row(
                children: _isBuy 
                  ? [25, 50, 100, 250].map((amt) {
                      final sel = _amount == amt;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _amount = amt.toDouble();
                            _ctrl.text = amt.toString();
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: sel ? sideBg : t.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: sel ? sideFg : t.border),
                            ),
                            child: Text('\$$amt',
                                style: TextStyle(
                                    color: sel ? sideFg : t.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ),
                      );
                    }).toList()
                  : [
                      if (widget.maxShares != null) ...[
                        widget.maxShares! * 0.25,
                        widget.maxShares! * 0.5,
                        widget.maxShares! * 0.75,
                        widget.maxShares!,
                      ].map((amt) {
                        final sel = _amount == amt;
                        final label = amt == widget.maxShares ? 'MAX' : '${(amt / widget.maxShares! * 100).toStringAsFixed(0)}%';
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _amount = amt;
                              _ctrl.text = _formatShares(amt);
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: sel ? sideBg : t.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: sel ? sideFg : t.border),
                              ),
                              child: Text(label,
                                  style: TextStyle(
                                      color: sel ? sideFg : t.textMuted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ),
                          ),
                        );
                      }).toList()
                    ],
              ),
              const SizedBox(height: 16),
              
              // Pricing breakdown box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  children: [
                    _PreviewRow(
                        label: 'Average Price',
                        value: TradeMath.formatPrice(price),
                        t: t),
                    if (_isBuy) ...[
                      _PreviewRow(
                          label: 'Estimated Shares',
                          value: _formatShares(estShares),
                          t: t),
                      _PreviewRow(
                          label: 'Potential Payout',
                          value: '\$${estPayout.toStringAsFixed(2)}',
                          t: t),
                      _PreviewRow(
                          label: 'Estimated Profit',
                          value: '\$${profit.toStringAsFixed(2)}',
                          t: t,
                          isLast: true),
                    ] else ...[
                      _PreviewRow(
                          label: 'Estimated Payout',
                          value: '\$${estPayout.toStringAsFixed(2)} USDC',
                          t: t),
                      _PreviewRow(
                          label: 'Shares Owned',
                          value: '${widget.maxShares != null ? _formatShares(widget.maxShares!) : "0"} $sideLabel',
                          t: t,
                          isLast: true),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasRealWallet
                      ? t.yesBg
                      : PulsColors.amberLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasRealWallet
                          ? (widget.market.contractAddress != null
                              ? Icons.bolt_rounded
                              : Icons.check_circle_outline_rounded)
                          : Icons.info_outline_rounded,
                      color: hasRealWallet ? t.yes : PulsColors.amber,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasRealWallet
                            ? (widget.market.contractAddress != null
                                ? '⚡ Instant trade — already on Arc Testnet · \$${ws.usdcBalance}'
                                : 'Real USDC trade on Arc Testnet · Balance: \$${ws.usdcBalance}')
                            : 'Demo only — connect wallet in Profile for real trades.',
                        style: TextStyle(
                          color: hasRealWallet
                              ? t.yes
                              : PulsColors.amber,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: (_amount > 0 && !_isExecuting)
                      ? () async {
                          final snack = PulsSnack.of(context);
                          setState(() => _isExecuting = true);
                          try {
                            if (hasRealWallet) {
                              final Map<String, dynamic> result;
                              if (_isLimit) {
                                result = await walletService.placeLimitOrder(
                                  isBuy: _isBuy,
                                  isYes: isYes,
                                  amount: _amount,
                                  targetPrice: _limitPrice,
                                  slug: widget.market.slug,
                                  marketId: widget.market.contractAddress ?? '',
                                  deadline: widget.market.deadline.millisecondsSinceEpoch ~/ 1000,
                                );
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                snack.show(
                                    '🎯 Limit order placed to ${_isBuy ? "buy" : "sell"} $sideLabel at \$${_limitPrice.toStringAsFixed(2)}');
                              } else {
                                if (_isBuy) {
                                  result = await walletService.buyPosition(
                                    isYes: isYes,
                                    usdcAmount: _amount,
                                    question: widget.market.question,
                                    entryPrice: price,
                                    contractAddress: widget.market.contractAddress,
                                    slug: widget.market.slug,
                                    deadline: widget.market.deadline.millisecondsSinceEpoch ~/ 1000,
                                  );
                                } else {
                                  result = await walletService.sellPosition(
                                    isYes: isYes,
                                    shares: _amount,
                                    question: widget.market.question,
                                    entryPrice: price,
                                    contractAddress: widget.market.contractAddress,
                                    slug: widget.market.slug,
                                    deadline: widget.market.deadline.millisecondsSinceEpoch ~/ 1000,
                                    owner: widget.owner,
                                  );
                                }
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                TxStatusSheet.show(
                                  context,
                                  txId: result['txId'] as String,
                                  side: isYes ? 'YES' : 'NO',
                                  amount: _amount,
                                  isBuy: _isBuy,
                                  walletService: walletService,
                                );
                              }
                            } else {
                              // Demo trade
                              if (_isBuy) {
                                appState.addDemoPosition(
                                  market: widget.market,
                                  side: widget.side,
                                  amount: _amount,
                                );
                              } else {
                                // Demo sell (remove from portfolio)
                                // Just pop for simplicity in demo mode
                              }
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                              snack.show(_isBuy
                                  ? 'Added demo ${isYes ? 'Yes' : 'No'} position.'
                                  : 'Sold demo ${isYes ? 'Yes' : 'No'} position.');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              snack.error(
                                  e.toString().contains('Insufficient')
                                      ? e.toString().replaceFirst('Exception: ', '')
                                      : 'Trade failed: $e',
                                  duration: const Duration(seconds: 5));
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isExecuting = false;
                              });
                            }
                          }
                        }
                      : null,
                  style: TextButton.styleFrom(
                    backgroundColor: (_amount > 0 && !_isExecuting) ? sideFg : t.border,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isExecuting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            ),
                            if (_isExecuting) ...[
                              const SizedBox(width: 10),
                              const Text(
                                'Processing…',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        )
                      : Text(
                          hasRealWallet 
                              ? (_isBuy ? 'Buy $sideLabel with USDC' : 'Sell $sideLabel Shares for USDC')
                              : 'Confirm demo trade',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    required this.t,
    this.isLast = false,
  });
  final String label;
  final String value;
  final PulsThemeColors t;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: t.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
