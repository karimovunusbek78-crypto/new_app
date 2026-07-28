import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/notification/app_notification.dart';
import 'package:new_app/src/pages/home/notification/notifications_provider.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/video/video%20page/profile/user_stats_page.dart';


/// Полный список уведомлений: лайки, комментарии, ответы, подписки.
/// Тап по элементу открывает объявление (для like/comment/reply) или
/// профиль подписавшегося (для subscribe), и помечает его прочитанным.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _ink = Color(0xFF0F0F0F);
  static const _grey = Color(0xFF6B6B70);
  static const _bg = Color(0xFFF7F7F8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsProvider>().markAllRead();
    });
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин.';
    if (diff.inHours < 24) return '${diff.inHours} ч.';
    if (diff.inDays < 30) return '${diff.inDays} дн.';
    final months = (diff.inDays / 30).floor().clamp(1, 11);
    return '$months мес.';
  }

  Future<void> _openNotification(AppNotification n) async {
    context.read<NotificationsProvider>().markRead(n.id);

    if (n.type == AppNotificationType.subscribe) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserStatsPage(uid: n.fromUid)),
      );
      return;
    }

    // like / comment / reply — ведём на страницу объявления, если оно
    // ещё существует в CarsProvider.
    final carId = n.carId;
    if (carId == null) return;
    final car = context.read<CarsProvider>().carById(carId);
    if (car == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Объявление больше недоступно')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CarDetailPage(car: car)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<NotificationsProvider>().items;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: _bg,
        centerTitle: false,
        title: Text(
          'Уведомления',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 17.sp),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEFEFEF)),
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 6.h, color: const Color(0xFFC8C8CC)),
                    SizedBox(height: 1.5.h),
                    Text(
                      'Пока нет уведомлений',
                      style: TextStyle(fontSize: 13.sp, color: _grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.symmetric(vertical: 1.h),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, indent: 20.w, color: const Color(0xFFF0F0F0)),
              itemBuilder: (context, i) {
                final n = items[i];
                final hasAvatar = n.fromAvatarUrl != null && n.fromAvatarUrl!.isNotEmpty;
                final initials = n.fromName.isNotEmpty ? n.fromName[0].toUpperCase() : '?';

                return ListTile(
                  onTap: () => _openNotification(n),
                  tileColor: n.read ? Colors.transparent : const Color(0xFFEAF4FF),
                  contentPadding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 0.6.h),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 5.5.w,
                        backgroundColor: Colors.black12,
                        backgroundImage: hasAvatar ? NetworkImage(n.fromAvatarUrl!) : null,
                        child: hasAvatar
                            ? null
                            : Text(initials,
                                style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black54)),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: n.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: _bg, width: 2),
                          ),
                          child: Icon(n.icon, size: 11, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    n.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.8.sp,
                      fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                      color: _ink,
                      height: 1.3,
                    ),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 0.4.h),
                    child: Text(
                      _timeAgo(n.createdAt),
                      style: TextStyle(fontSize: 10.5.sp, color: _grey),
                    ),
                  ),
                  trailing: !n.read
                      ? Container(
                          width: 2.2.w,
                          height: 2.2.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4DA6FF),
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                );
              },
            ),
    );
  }
}