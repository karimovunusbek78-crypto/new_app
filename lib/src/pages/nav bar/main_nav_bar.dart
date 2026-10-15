import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_app/src/video/controller/main_tab_controller.dart';
import 'package:provider/provider.dart';
import 'package:new_app/src/video/video%20page/video_page.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:new_app/src/pages/profile/profile_page.dart';
import 'package:new_app/src/pages/add/add_page.dart';

class MainNavBar extends StatefulWidget {
  const MainNavBar({Key? key}) : super(key: key);

  @override
  State<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends State<MainNavBar> {
  late final List<Widget> _pages;

  // Индекс таба "Видео" — именно для него нижний бар переключается
  // в тёмный стиль (белый бар поверх чёрной ленты выглядел чужеродно).
  static const int _videoTabIndex = 2;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(onSearchTap: () => _onTap(1)),
      const SearchPage(),
      const VideoPage(),
      const ProfilePage(),
    ];
  }

  void _onTap(int index) {
    final nav = context.read<NavTabController>();
    if (index == nav.currentIndex) return;
    HapticFeedback.lightImpact();
    nav.setIndex(index);
  }

  void _onAddTap() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPage()),
    );
  }

  final List<_NavItemData> _items = const [
    _NavItemData(icon: Icons.home_rounded,            label: 'Главная'),
    _NavItemData(icon: Icons.search_rounded,          label: 'Поиск'),
    _NavItemData(icon: Icons.play_circle_fill_rounded, label: 'Видео'),
    _NavItemData(icon: Icons.person_rounded,          label: 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.watch<NavTabController>().currentIndex;
    final isDark = currentIndex == _videoTabIndex;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _FadeIndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _BottomNav(
        items: _items,
        currentIndex: currentIndex,
        isDark: isDark,
        onTap: _onTap,
        onAddTap: _onAddTap,
      ),
    );
  }
}

// ── Cross-fading page container (keeps every page alive) ────────────────────────

class _FadeIndexedStack extends StatelessWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const _FadeIndexedStack({
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 280),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: List.generate(children.length, (i) {
        final active = i == index;
        return AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: duration,
          curve: Curves.easeInOut,
          child: AnimatedScale(
            scale: active ? 1 : 0.98,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: IgnorePointer(
              ignoring: !active,
              child: TickerMode(
                enabled: active,
                child: children[i],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}

class _BottomNav extends StatelessWidget {
  final List<_NavItemData> items;
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;

  const _BottomNav({
    required this.items,
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C0C0C) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFEEEEEE),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.5)
                    : Colors.black.withOpacity(0.06),
                blurRadius: 2.h,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 8.h,
              child: Row(
                children: [
                  _NavItem(data: items[0], index: 0, isActive: currentIndex == 0, isDark: isDark, onTap: onTap),
                  _NavItem(data: items[1], index: 1, isActive: currentIndex == 1, isDark: isDark, onTap: onTap),
                  SizedBox(width: 18.w),
                  _NavItem(data: items[2], index: 2, isActive: currentIndex == 2, isDark: isDark, onTap: onTap),
                  _NavItem(data: items[3], index: 3, isActive: currentIndex == 3, isDark: isDark, onTap: onTap),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -0.7.h,
          child: _AddButton(onTap: onAddTap, isDark: isDark),
        ),
      ],
    );
  }
}

// ── Center add button (press feedback + playful spin) ──────────────────────────

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDark;
  const _AddButton({required this.onTap, required this.isDark});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    // На тёмном баре кнопка "+" становится белой с тёмной иконкой —
    // фиолетовая на чёрном фоне теряла контраст с остальным UI ленты.
    final bg = widget.isDark ? Colors.white : const Color(0xFF2D1B6E);
    final iconColor = widget.isDark ? const Color(0xFF0C0C0C) : Colors.white;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 6.h,
          height: 6.h,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: bg.withOpacity(_down ? 0.5 : 0.35),
                blurRadius: _down ? 18 : 12,
                offset: Offset(0, _down ? 6 : 4),
              ),
            ],
          ),
          child: AnimatedRotation(
            turns: _down ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Icon(
              Icons.add_rounded,
              color: iconColor,
              size: 3.2.h,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav item (press feedback + active bounce) ──────────────────────────────────

class _NavItem extends StatefulWidget {
  final _NavItemData data;
  final int index;
  final bool isActive;
  final bool isDark;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.data,
    required this.index,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final isDark = widget.isDark;

    // Тёмный бар: активный — белый, неактивный — приглушённый серый.
    // Светлый бар: поведение как раньше (тёмно-фиолетовый / светло-серый).
    final activeColor = isDark ? Colors.white : const Color.fromARGB(255, 5, 2, 19);
    final inactiveColor = isDark ? Colors.white38 : const Color(0xFFBBBBBB);
    final activeHighlight = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color.fromARGB(255, 5, 2, 16).withOpacity(0.1);

    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onTap(widget.index),
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _down ? 0.86 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isActive ? 1.0 : 0.92,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: 3.5.w,
                    vertical: 0.8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? activeHighlight : Colors.transparent,
                    borderRadius: BorderRadius.circular(1.5.h),
                  ),
                  child: Icon(
                    widget.data.icon,
                    size: 2.8.h,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                ),
              ),
              SizedBox(height: 0.4.h),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
                child: Text(widget.data.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}