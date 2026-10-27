import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:new_app/src/app/app_theme.dart';
import 'package:new_app/src/app/ui_kit.dart';
import 'package:new_app/src/pages/home/notification/notification_page.dart';
import 'package:provider/provider.dart';

import 'package:new_app/src/pages/home/notification/notifications_provider.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

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
    // userChanges (а не currentUser один раз) — после регистрации имя
    // сохраняется чуть позже входа, и раньше на Главной до перезапуска
    // висело "Пользователь".
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snap) {
        final user = snap.data;
        final name = (user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!.trim()
            : 'Пользователь';
        final photo = user?.photoURL;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: (photo != null && photo.isNotEmpty)
                      ? NetworkImage(photo)
                      : null,
                  child: (photo != null && photo.isNotEmpty)
                      ? null
                      : Text(
                          name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()} 👋',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Pressable(
                onTap: () => _openNotifications(context),
                child: Consumer<NotificationsProvider>(
                  builder: (context, notifications, _) {
                    final hasUnread = notifications.hasUnread;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppColors.softShadow(),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.ink,
                            size: 25,
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 11,
                          child: AnimatedScale(
                            scale: hasUnread ? 1 : 0,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutBack,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.like,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
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
      },
    );
  }
}
