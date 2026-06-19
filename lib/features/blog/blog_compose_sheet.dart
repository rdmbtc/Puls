import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../app/puls_app.dart';
import '../wallet/wallet_service.dart';

/// A simple compose sheet for humans to publish a blog post (markdown body).
class BlogComposeSheet extends StatefulWidget {
  const BlogComposeSheet({super.key});

  @override
  State<BlogComposeSheet> createState() => _BlogComposeSheetState();
}

class _BlogComposeSheetState extends State<BlogComposeSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _tags = TextEditingController();
  final _cover = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    _cover.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty || _busy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required')),
      );
      return;
    }
    setState(() => _busy = true);
    final wallet = WalletServiceScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final tags = _tags.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final res = await wallet.createBlogPost(
        title: title,
        body: body,
        tags: tags,
        coverUrl: _cover.text.trim().isEmpty ? null : _cover.text.trim(),
      );
      if (res['ok'] == true) {
        messenger.showSnackBar(const SnackBar(content: Text('Published 🎉 +20 XP')));
        navigator.pop(true);
      } else {
        messenger.showSnackBar(SnackBar(content: Text('${res['message'] ?? res['error'] ?? 'Could not publish'}')));
        setState(() => _busy = false);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Publish failed: $e')));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: t.border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2))),
          ),
          Text('Write a post', style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text('Markdown supported (## headers, **bold**, lists, links).',
              style: TextStyle(color: t.textMuted, fontSize: 12)),
          const SizedBox(height: 14),
          _field(t, _title, 'Title', maxLines: 1),
          const SizedBox(height: 10),
          _field(t, _body, 'Write your analysis…', maxLines: 8),
          const SizedBox(height: 10),
          _field(t, _cover, 'Cover image URL (optional)', maxLines: 1),
          const SizedBox(height: 10),
          _field(t, _tags, 'Tags (comma-separated, optional)', maxLines: 1),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: t.brand, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Publish', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(PulsThemeColors t, TextEditingController c, String hint, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 4 : 1,
      style: TextStyle(color: t.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: t.textSubtle, fontSize: 14),
        filled: true,
        fillColor: t.surfaceRaised.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.brand)),
      ),
    );
  }
}
