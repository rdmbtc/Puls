import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/app/puls_app.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final wallet = WalletServiceScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await wallet.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    final wallet = WalletServiceScope.of(context);
    try {
      await wallet.markNotificationsRead();
      _load();
    } catch (_) {}
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'trade':
        return Icons.bolt_rounded;
      case 'resolution':
        return Icons.auto_awesome_rounded;
      case 'limit_order':
        return Icons.track_changes_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getColorForType(String type, PulsThemeColors t) {
    switch (type) {
      case 'trade':
        return t.yes;
      case 'resolution':
        return Colors.purpleAccent;
      case 'limit_order':
        return PulsColors.amber;
      default:
        return t.brand;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = !context.isDark;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_notifications.any((n) => n['read'] == false))
            TextButton.icon(
              onPressed: _markAllRead,
              icon: Icon(Icons.done_all_rounded, size: 16, color: t.brand),
              label: Text('Mark Read', style: TextStyle(color: t.brand, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: t.brand,
          onRefresh: _load,
          child: _loading
              ? Center(child: CircularProgressIndicator(color: t.brand, strokeWidth: 2))
              : _error != null
                  ? Center(child: Text('Error loading notifications: $_error', style: TextStyle(color: t.no)))
                  : _notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: t.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: t.border),
                                ),
                                child: Icon(Icons.notifications_none_rounded, color: t.textSubtle, size: 28),
                              ),
                              const SizedBox(height: 16),
                              Text('All Caught Up!', style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 6),
                              Text('No new notifications right now.', style: TextStyle(color: t.textSubtle, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final notification = _notifications[i];
                            final read = notification['read'] as bool? ?? false;
                            final type = notification['type'] as String? ?? 'system';
                            final color = _getColorForType(type, t);
                            final icon = _getIconForType(type);

                            return FadeInRight(
                              delay: Duration(milliseconds: i * 30),
                              duration: const Duration(milliseconds: 250),
                              child: GestureDetector(
                                onTap: () async {
                                  if (!read) {
                                    await WalletServiceScope.of(context).markNotificationsRead(notificationId: notification['id']);
                                    _load();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: read 
                                        ? t.surface 
                                        : (isDark ? const Color(0xFF1B1933) : const Color(0xFFEEEDFC)),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: read ? t.border : t.brand.withValues(alpha: 0.3),
                                      width: read ? 1.0 : 1.5,
                                    ),
                                    boxShadow: [
                                      if (!read)
                                        BoxShadow(
                                          color: t.brand.withValues(alpha: 0.08),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(icon, color: color, size: 18),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    notification['title'] ?? 'Alert',
                                                    style: TextStyle(
                                                      color: t.text,
                                                      fontSize: 13,
                                                      fontWeight: read ? FontWeight.bold : FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                                if (!read)
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: t.brand,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              notification['message'] ?? '',
                                              style: TextStyle(
                                                color: read ? t.textSubtle : t.text,
                                                fontSize: 12,
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _timeAgo(notification['created_at']),
                                              style: TextStyle(
                                                color: t.textMuted,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return '';
    }
  }
}
