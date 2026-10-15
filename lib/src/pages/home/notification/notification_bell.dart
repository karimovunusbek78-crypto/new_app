import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/notification/notification_page.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/notification/notifications_provider.dart';

/// Иконка-колокольчик уведомлений. Синеет и заполняется (плюс маленькая
/// синяя точка сверху справа), когда есть непрочитанные уведомления.
/// Тап — открывает полный список (NotificationsPage).
///
/// Использование (например в HomeHeader/AppBar):
///   const NotificationBell()
/// или с явным цветом обычного (непрочитанного) состояния:
///   const NotificationBell(idleColor: Colors.white)
class NotificationBell extends StatelessWidget {
  final Color? idleColor;
  final double? size;

  const NotificationBell({super.key, this.idleColor, this.size});

  static const _accent = Color(0xFF4DA6FF);

  @override
  Widget build(BuildContext context) {
    final hasUnread = context.watch<NotificationsProvider>().hasUnread;
    final iconSize = size ?? 2.7.h;

    return GestureDetector(
      onTap: () {
        context.read<NotificationsProvider>().markAllRead();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.all(1.w),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                hasUnread ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                key: ValueKey(hasUnread),
                color: hasUnread ? _accent : (idleColor ?? Colors.black87),
                size: iconSize,
              ),
            ),
            if (hasUnread)
              Positioned(
                right: -0.5.w,
                top: -0.3.h,
                child: Container(
                  width: 2.2.w,
                  height: 2.2.w,
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}