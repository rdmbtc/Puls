import 'package:flutter/material.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/app/puls_app.dart';

class CreateMarketDialog extends StatefulWidget {
  const CreateMarketDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const CreateMarketDialog(),
    );
  }

  @override
  State<CreateMarketDialog> createState() => _CreateMarketDialogState();
}

class _CreateMarketDialogState extends State<CreateMarketDialog> {
  final _formKey = GlobalKey<FormState>();
  final _questionCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  
  String _category = 'Crypto';
  DateTime? _deadline;
  TimeOfDay? _deadlineTime;
  
  bool _submitting = false;
  String? _error;

  final _categories = ['Crypto', 'Politics', 'Finance', 'Tech', 'Science', 'Sports', 'General'];

  @override
  void dispose() {
    _questionCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) {
      setState(() => _deadlineTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deadline == null) {
      setState(() => _error = 'Please select a resolution date');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final wallet = WalletServiceScope.of(context);

    // Combine Date and Time
    final time = _deadlineTime ?? const TimeOfDay(hour: 12, minute: 0);
    final finalDeadline = DateTime(
      _deadline!.year,
      _deadline!.month,
      _deadline!.day,
      time.hour,
      time.minute,
    );

    try {
      final deadlineUnix = finalDeadline.millisecondsSinceEpoch ~/ 1000;
      await wallet.createCustomMarket(
        question: _questionCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        deadline: deadlineUnix,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.puls.yes,
            content: const Text('🎉 Custom market deployed and funded successfully on Arc Testnet!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().contains('Insufficient')
              ? e.toString().replaceFirst('Exception: ', '')
              : 'Failed to deploy market: $e';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final wallet = WalletServiceScope.of(context);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: t.brandSubtle,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add_chart_rounded, color: t.brand, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Create Custom Market',
                          style: TextStyle(
                            color: t.text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(Icons.close_rounded, color: t.textSubtle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Question Field
                  TextFormField(
                    controller: _questionCtrl,
                    style: TextStyle(color: t.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Market Question',
                      labelStyle: TextStyle(color: t.textSubtle, fontSize: 13),
                      hintText: 'e.g. Will Bitcoin end the year above \$100,000?',
                      hintStyle: TextStyle(color: t.textMuted, fontSize: 13),
                    ),
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a question' : null,
                  ),
                  const SizedBox(height: 16),

                  // Description Field
                  TextFormField(
                    controller: _descCtrl,
                    style: TextStyle(color: t.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Resolution Source / Description',
                      labelStyle: TextStyle(color: t.textSubtle, fontSize: 13),
                      hintText: 'e.g. Resolves yes based on Coinbase BTC-USD close price on Dec 31.',
                      hintStyle: TextStyle(color: t.textMuted, fontSize: 13),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Category Selector
                  DropdownButtonFormField<String>(
                    value: _category,
                    dropdownColor: t.surfaceRaised,
                    style: TextStyle(color: t.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: t.textSubtle, fontSize: 13),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Deadline Selection Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectDate,
                          icon: Icon(Icons.calendar_month_rounded, size: 16, color: t.brand),
                          label: Text(
                            _deadline == null 
                                ? 'Pick Date' 
                                : '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                            style: TextStyle(color: t.text, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: t.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectTime,
                          icon: Icon(Icons.access_time_rounded, size: 16, color: t.brand),
                          label: Text(
                            _deadlineTime == null 
                                ? 'Pick Time' 
                                : _deadlineTime!.format(context),
                            style: TextStyle(color: t.text, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: t.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Lockup warning box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.yesBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.yes.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: t.yes, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Initial Liquidity locked: 10.00 USDC',
                                style: TextStyle(color: t.yes, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Deploying is fully on-chain. The funding fee is deducted from your balance to seed the LMSR AMM pool. Current balance: \$${wallet.state.usdcBalance}',
                                style: TextStyle(color: t.yes.withValues(alpha: 0.8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: TextStyle(color: t.no, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],

                  const SizedBox(height: 20),

                  // Actions
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _submitting ? null : _submit,
                      style: TextButton.styleFrom(
                        backgroundColor: t.brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Deploy & Fund Market',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
