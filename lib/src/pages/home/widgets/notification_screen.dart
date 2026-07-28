import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class NotificationItem {
  final String title;
  final String subtitle;
  final String time;
  final bool isRead;
  final NotificationType type;

  const NotificationItem({
    required this.title,
    required this.subtitle,
    required this.time,
    this.isRead = false,
    required this.type,
  });
}

enum NotificationType { subscription, message, system }

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Тестовые данные — замени на свои реальные
  final List<NotificationItem> notifications = const [
    NotificationItem(
      title: 'Новая подписка',
      subtitle: 'Иван Петров подписался на вас',
      time: '2 мин назад',
      type: NotificationType.subscription,
    ),
    NotificationItem(
      title: 'Новое сообщение',
      subtitle: 'Анна: Привет! Как дела?',
      time: '5 мин назад',
      type: NotificationType.message,
    ),
    NotificationItem(
      title: 'Новая подписка',
      subtitle: 'Мария Сидорова подписалась на вас',
      time: '10 мин назад',
      isRead: true,
      type: NotificationType.subscription,
    ),
    NotificationItem(
      title: 'Новое сообщение',
      subtitle: 'Алексей: Увидимся завтра?',
      time: '1 ч назад',
      isRead: true,
      type: NotificationType.message,
    ),
    NotificationItem(
      title: 'Системное уведомление',
      subtitle: 'Ваш профиль был обновлён',
      time: '2 ч назад',
      isRead: true,
      type: NotificationType.system,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.subscription:
        return Icons.person_add_outlined;
      case NotificationType.message:
        return Icons.chat_bubble_outline;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  Color _colorFor(NotificationType type) {
    switch (type) {
      case NotificationType.subscription:
        return const Color(0xFF3A6FF8);
      case NotificationType.message:
        return const Color(0xFF34C759);
      case NotificationType.system:
        return const Color(0xFFFF9500);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Scaffold(
          backgroundColor: const Color(0xFFF2F2F7),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF2F2F7),
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Color(0xFF1C1C1E), size: 18),
              ),
            ),
            title: Text(
              'Уведомления',
              style: TextStyle(
                color: const Color(0xFF1C1C1E),
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {},
                child: Text(
                  'Очистить',
                  style: TextStyle(
                    color: const Color(0xFF3A6FF8),
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ],
          ),
          body: notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 15.w, color: Colors.black26),
                      SizedBox(height: 2.h),
                      Text(
                        'Нет уведомлений',
                        style: TextStyle(
                            color: Colors.black38, fontSize: 14.sp),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(4.w),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => SizedBox(height: 1.5.h),
                  itemBuilder: (_, i) {
                    final n = notifications[i];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + i * 60),
                      curve: Curves.easeOut,
                      builder: (context, val, child) => Opacity(
                        opacity: val,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - val)),
                          child: child,
                        ),
                      ),
                      child: ClipRRect(
                        // Клип нужен, чтобы синяя полоска слева не вылезала
                        // за скруглённые углы карточки.
                        borderRadius: BorderRadius.circular(3.w),
                        child: Stack(
                          children: [
                            Container(
                              padding: EdgeInsets.all(3.5.w),
                              decoration: BoxDecoration(
                                color: n.isRead
                                    ? Colors.white
                                    : const Color(0xFFEEF3FF),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Небольшой отступ слева под полоску,
                                  // чтобы контент не наезжал на неё.
                                  if (!n.isRead) SizedBox(width: 2.5.w),
                                  Container(
                                    width: 11.w,
                                    height: 11.w,
                                    decoration: BoxDecoration(
                                      color: _colorFor(n.type)
                                          .withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _iconFor(n.type),
                                      color: _colorFor(n.type),
                                      size: 5.w,
                                    ),
                                  ),
                                  SizedBox(width: 3.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              n.title,
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    const Color(0xFF1C1C1E),
                                              ),
                                            ),
                                            Text(
                                              n.time,
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                color:
                                                    const Color(0xFF8E8E93),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 0.4.h),
                                        Text(
                                          n.subtitle,
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: const Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!n.isRead)
                                    Container(
                                      width: 2.w,
                                      height: 2.w,
                                      margin: EdgeInsets.only(left: 2.w),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF3A6FF8),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // ── Синяя полоска слева для непрочитанных ──
                            if (!n.isRead)
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 1.2.w,
                                  color: const Color(0xFF3A6FF8),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}