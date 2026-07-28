import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/notification/notification_page.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/notification/notifications_provider.dart';

class HomeHeader extends StatelessWidget {
  final String displayName;

  const HomeHeader({super.key, required this.displayName});

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Доброе утро';
    } else if (hour >= 12 && hour < 17) {
      return 'Добрый день';
    } else if (hour >= 17 && hour < 23) {
      return 'Добрый вечер';
    } else {
      return 'Доброй ночи';
    }
  }

  void _openNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 0.4.h),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => _openNotifications(context),
            behavior: HitTestBehavior.opaque,
            child: Consumer<NotificationsProvider>(
              builder: (context, notifications, _) {
                final hasUnread = notifications.hasUnread;
                return Stack(
                  children: [
                    Container(
                      width: 11.w,
                      height: 11.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: const Color(0xFF1C1C1E),
                        size: 2.5.h,
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        top: 1.w,
                        right: 1.w,
                        child: Container(
                          width: 2.w,
                          height: 2.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3A6FF8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}