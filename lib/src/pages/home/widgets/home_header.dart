import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'notification_screen.dart';

class HomeHeader extends StatefulWidget {
  final String displayName;
  final int notificationCount;

  const HomeHeader({
    super.key,
    required this.displayName,
    this.notificationCount = 0,
  });

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  // Защита от множественных тапов по колокольчику: без неё каждый тап
  // (в том числе за то время, пока ждёт Future.delayed) добавлял в стек
  // ещё одну копию NotificationScreen, и один pop закрывал только
  // верхнюю — казалось, что "не могу выйти с одного раза".
  bool _isOpeningNotifications = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    // Уже открываем экран уведомлений — игнорируем повторные тапы,
    // пока навигация не завершится (см. сброс флага ниже).
    if (_isOpeningNotifications) return;
    _isOpeningNotifications = true;

    _controller.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => const NotificationScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            );
          },
        ),
      ).then((_) {
        // Экран уведомлений закрылся — снова разрешаем открыть его.
        if (mounted) {
          setState(() => _isOpeningNotifications = false);
        } else {
          _isOpeningNotifications = false;
        }
      });
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12)
      return 'Доброе утро';
    else if (hour >= 12 && hour < 17)
      return 'Добрый день';
    else if (hour >= 17 && hour < 23)
      return 'Добрый вечер';
    else
      return 'Доброй ночи';
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
                widget.displayName,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),

          GestureDetector(
            onTap: _onTap,
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              ),
              child: Stack(
                clipBehavior: Clip.none,
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

                  // Точка — только если есть уведомления
                  if (widget.notificationCount > 0)
                    Positioned(
                      top: -1.w,
                      right: -1.w,
                      child: Container(
                        padding: EdgeInsets.all(0.8.w),
                        constraints: BoxConstraints(
                          minWidth: 4.5.w,
                          minHeight: 4.5.w,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.notificationCount > 99
                                ? '99+'
                                : '${widget.notificationCount}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}