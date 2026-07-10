import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/core/widgets/gradient_text.dart';
import 'package:puls/core/widgets/state_views.dart';
import 'package:puls/core/widgets/puls_loader.dart';
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
    } catch (e) {
      debugPrint('[Puls] mark notifications read failed: $e');
    }
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
        return t.brand; // on-brand pink (was off-brand purple)
      case 'limit_order':
        return PulsColors.amber;
      default:
        return t.brand;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const AnimatedGradientText('Notifications',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
              ? const PulsLoader()
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: PulsErrorState(
                          title: 'Couldn\'t load notifications',
                          message: 'Pull down to retry.',
                          onRetry: _load,
                        ),
                      ),
                    )
                  : _notifications.isEmpty
                      ? const Center(
                          child: PulsEmptyState(
                            icon: Icons.notifications_none_rounded,
                            title: 'All caught up!',
                            message: 'No new notifications right now.',
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
