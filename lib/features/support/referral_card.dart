import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config.dart' show backendUrl;
import '../../core/theme/app_theme.dart';

class ReferralCard extends StatefulWidget {
  const ReferralCard({super.key});

  @override
  State<ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<ReferralCard> {
  String? _code;
  String? _link;
  int _invitedCount = 0;
  bool _loading = true;
  final _claimCtrl = TextEditingController();
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _claimCtrl.dispose();
    super.dispose();
  }

  Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    final s = Supabase.instance.client.auth.currentSession;
    if (s != null) h['Authorization'] = 'Bearer ${s.accessToken}';
    return h;
  }

  Future<void> _fetch() async {
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/referrals/me'),
        headers: _headers,
      );
      if (res.statusCode != 200) throw Exception('Failed');
      final data = jsonDecode(res.body);
      if (mounted) {
        setState(() {
          _code = data['code'] as String?;
          _link = data['link'] as String?;
          _invitedCount = (data['invitedCount'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyLink() {
    if (_link == null) return;
    Clipboard.setData(ClipboardData(text: _link!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral link copied!'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _claimCode() async {
    final code = _claimCtrl.text.trim();
    if (code.isEmpty || _claiming) return;
    setState(() => _claiming = true);
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/referrals/claim'),
        headers: _headers,
        body: jsonEncode({'code': code}),
      );
      if (res.statusCode == 200) {
        _claimCtrl.clear();
        await _fetch();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Referral code applied!'), duration: Duration(seconds: 2)),
          );
        }
      } else {
        final data = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] as String? ?? 'Invalid code'), duration: const Duration(seconds: 2)),
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _claiming = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (_loading) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.brand.withValues(alpha: 0.14), t.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: t.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.people_rounded, color: t.brand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Refer a friend', style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('$_invitedCount friend${_invitedCount == 1 ? '' : 's'} invited',
                        style: TextStyle(color: t.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (_code != null && _link != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your code', style: TextStyle(color: t.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                        Text(_code!, style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _copyLink,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: t.brand,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Copy link', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Have a referral code?', style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _claimCtrl,
                  style: TextStyle(color: t.text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    hintStyle: TextStyle(color: t.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: t.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _claiming ? null : _claimCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: t.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.brand.withValues(alpha: 0.3)),
                  ),
                  child: _claiming
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: t.brand, strokeWidth: 2))
                      : Text('Apply', style: TextStyle(color: t.brand, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
