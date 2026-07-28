import 'dart:async';

import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/notification/app_navigator.dart';
import 'package:new_app/src/pages/home/notification/notification_page.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/video/video%20page/profile/user_stats_page.dart';

import 'package:new_app/src/pages/home/notification/app_notification.dart';
import 'package:new_app/src/pages/home/notification/notifications_provider.dart';

/// Оборачивает всё приложение и показывает синюю карточку-баннер,
/// сползающую сверху экрана, КАЖДЫЙ РАЗ когда приходит новое уведомление
/// (лайк, комментарий, ответ, подписка) — независимо от того, какой
/// экран сейчас открыт.
///
/// Подключение в main.dart:
///   return MaterialApp(
///     navigatorKey: appNavigatorKey,
///     builder: (context, child) => NotificationBannerHost(child: child!),
///     home: ...,
///   );
class NotificationBannerHost extends StatefulWidget {
  final Widget child;
  const NotificationBannerHost({super.key, required this.child});

  @override
  State<NotificationBannerHost> createState() => _NotificationBannerHostState();
}

class _NotificationBannerHostState extends State<NotificationBannerHost> {
  Timer? _hideTimer;
  AppNotification? _shown;

  void _present(AppNotification n) {
    _hideTimer?.cancel();
    setState(() => _shown = n);
    _hideTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _hideTimer?.cancel();
    if (mounted) setState(() => _shown = null);
    // Сообщаем провайдеру, что баннер обработан — иначе то же самое
    // уведомление снова попадёт в incoming при следующем notifyListeners.
    context.read<NotificationsProvider>().clearIncoming();
  }

  void _openTarget(AppNotification n) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    if (n.type == AppNotificationType.subscribe) {
      nav.push(MaterialPageRoute(builder: (_) => UserStatsPage(uid: n.fromUid)));
    } else {
      // Лайк/комментарий/ответ — ведём в общий список уведомлений,
      // откуда уже можно перейти к конкретному объявлению/комментарию.
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationsProvider>(
      builder: (context, provider, _) {
        final incoming = provider.incoming;
        if (incoming != null && incoming.id != _shown?.id) {
          // notifyListeners() уже отработал в build — планируем показ
          // баннера на следующий кадр, чтобы не звать setState во время
          // построения дерева.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _present(incoming);
          });
        }

        return Stack(
          children: [
            widget.child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: IgnorePointer(
                  ignoring: _shown == null,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    offset: _shown != null ? Offset.zero : const Offset(0, -1.5),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 260),
                      opacity: _shown != null ? 1 : 0,
                      child: _shown == null
                          ? const SizedBox.shrink()
                          : _BannerCard(
                              notification: _shown!,
                              onTap: () {
                                final n = _shown!;
                                _dismiss();
                                _openTarget(n);
                              },
                              onSwipeUp: _dismiss,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onSwipeUp;

  const _BannerCard({
    required this.notification,
    required this.onTap,
    required this.onSwipeUp,
  });

  static const _accent = Color(0xFF4DA6FF);

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final hasAvatar = n.fromAvatarUrl != null && n.fromAvatarUrl!.isNotEmpty;
    final initials = n.fromName.isNotEmpty ? n.fromName[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      child: GestureDetector(
        onTap: onTap,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -50) onSwipeUp();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.4.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(4.w),
            border: Border.all(color: _accent.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 10.5.w,
                height: 10.5.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3C),
                  shape: BoxShape.circle,
                  image: hasAvatar
                      ? DecorationImage(
                          image: NetworkImage(n.fromAvatarUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: hasAvatar
                    ? null
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                              color: Colors.white70, fontWeight: FontWeight.w800),
                        ),
                      ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(n.icon, size: 1.7.h, color: n.accentColor),
                        SizedBox(width: 1.2.w),
                        Text(
                          'Новое уведомление',
                          style: TextStyle(
                            color: n.accentColor,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 0.3.h),
                    Text(
                      n.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
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
  }
}