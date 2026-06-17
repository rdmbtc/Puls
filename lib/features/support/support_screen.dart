import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config.dart' show backendUrl;
import '../../core/theme/app_theme.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    final s = Supabase.instance.client.auth.currentSession;
    if (s != null) h['Authorization'] = 'Bearer ${s.accessToken}';
    return h;
  }

  Future<void> _fetch() async {
    try {
      // Identity comes from the Bearer token; the server derives the verified
      // `supabase_<uuid>` id itself. Do NOT pass ?userId= (the raw Supabase uuid
      // mismatches the server's expected `supabase_` id and 403s).
      final res = await http.get(
        Uri.parse('$backendUrl/api/support/tickets'),
        headers: _headers,
      );
      if (res.statusCode != 200) throw Exception('Failed');
      final data = jsonDecode(res.body);
      final list = (data['tickets'] as List? ?? [])
          .map((t) => t as Map<String, dynamic>)
          .toList();
      if (mounted) setState(() { _tickets = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _newTicket() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewTicketSheet(
        headers: _headers,
        onCreated: () { _fetch(); },
      ),
    );
  }

  void _openTicket(Map<String, dynamic> ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TicketDetailScreen(
          ticketId: '${ticket['id']}',
          subject: ticket['subject'] as String? ?? 'Support',
          headers: _headers,
        ),
      ),
    ).then((_) => _fetch());
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'open': return 'Open';
      case 'answered': return 'Answered';
      case 'closed': return 'Closed';
      default: return status ?? '';
    }
  }

  Color _statusColor(String? status, PulsThemeColors t) {
    switch (status) {
      case 'open': return PulsColors.amber;
      case 'answered': return t.yes;
      case 'closed': return t.textMuted;
      default: return t.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text('Support', style: TextStyle(color: t.text, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.text, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newTicket,
        backgroundColor: t.brand,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: t.brand))
          : _error != null
              ? Center(child: Text('Couldn\'t load tickets. Pull to retry.', style: TextStyle(color: t.textMuted)))
              : RefreshIndicator(
                  color: t.brand,
                  onRefresh: _fetch,
                  child: _tickets.isEmpty ? _buildEmpty(t) : _buildList(t),
                ),
    );
  }

  Widget _buildEmpty(PulsThemeColors t) {
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        const SizedBox(height: 60),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: t.brand.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.support_agent_rounded, color: t.brand, size: 32),
        ),
        const SizedBox(height: 20),
        Text('Need help?', textAlign: TextAlign.center,
            style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Open a ticket — we usually reply within a day.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textMuted, fontSize: 14, height: 1.4)),
      ],
    );
  }

  Widget _buildList(PulsThemeColors t) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: _tickets.length,
      itemBuilder: (context, i) {
        final ticket = _tickets[i];
        final status = ticket['status'] as String?;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _openTicket(ticket),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket['subject'] as String? ?? 'Support',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_statusLabel(status)} · ${ticket['messageCount'] ?? 0} messages',
                          style: TextStyle(color: t.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status, t).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: _statusColor(status, t),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet({required this.headers, required this.onCreated});
  final Map<String, String> headers;
  final VoidCallback onCreated;

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (subject.isEmpty || body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/support/tickets'),
        headers: widget.headers,
        body: jsonEncode({'subject': subject, 'body': body}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        widget.onCreated();
        if (mounted) Navigator.of(context).pop();
      } else {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error']?.toString() ?? 'Couldn\'t create ticket (${res.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong — try again.')),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Support Ticket',
                style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectCtrl,
              style: TextStyle(color: t.text, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Subject',
                labelStyle: TextStyle(color: t.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 5,
              minLines: 3,
              style: TextStyle(color: t.text, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'How can we help?',
                labelStyle: TextStyle(color: t.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.border),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _sending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.brand,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketDetailScreen extends StatefulWidget {
  const _TicketDetailScreen({
    required this.ticketId,
    required this.subject,
    required this.headers,
  });

  final String ticketId;
  final String subject;
  final Map<String, String> headers;

  @override
  State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<_TicketDetailScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  final _inputCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/support/tickets/${widget.ticketId}'),
        headers: widget.headers,
      );
      if (res.statusCode != 200) throw Exception('Failed');
      final data = jsonDecode(res.body);
      final ticket = data['ticket'] as Map<String, dynamic>? ?? data;
      final msgs = (ticket['messages'] as List? ?? [])
          .map((m) => m as Map<String, dynamic>)
          .toList();
      if (mounted) setState(() { _messages = msgs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _send() async {
    final body = _inputCtrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/support/tickets/${widget.ticketId}/messages'),
        headers: widget.headers,
        body: jsonEncode({'body': body}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        _inputCtrl.clear();
        await _fetch();
      } else {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error']?.toString() ?? 'Couldn\'t send message (${res.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong — try again.')),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(widget.subject, style: TextStyle(color: t.text, fontWeight: FontWeight.w700, fontSize: 15)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.text, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: t.brand))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      final isAdmin = msg['sender'] == 'admin';
                      return Align(
                        alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isAdmin ? t.surface : t.brand,
                            borderRadius: BorderRadius.circular(14),
                            border: isAdmin ? Border.all(color: t.border) : null,
                          ),
                          child: Text(
                            msg['body'] as String? ?? '',
                            style: TextStyle(
                              color: isAdmin ? t.text : Colors.white,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(top: BorderSide(color: t.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    maxLines: 3,
                    minLines: 1,
                    style: TextStyle(color: t.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: TextStyle(color: t.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: t.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: t.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: t.brand,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _sending
                        ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
