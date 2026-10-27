import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_app/src/video/controller/main_tab_controller.dart';
import 'package:provider/provider.dart';
import 'package:new_app/src/video/video%20page/video_page.dart';
import 'package:new_app/src/app/app_theme.dart';
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
      HomePage(
        onSearchTap: () {
          HapticFeedback.lightImpact();
          context.read<NavTabController>().openSearch();
        },
      ),
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPage()));
  }

  final List<_NavItemData> _items = const [
    _NavItemData(icon: Icons.home_rounded, label: 'Главная'),
    _NavItemData(icon: Icons.search_rounded, label: 'Поиск'),
    _NavItemData(icon: Icons.play_circle_fill_rounded, label: 'Видео'),
    _NavItemData(icon: Icons.person_rounded, label: 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.watch<NavTabController>().currentIndex;
    final isDark = currentIndex == _videoTabIndex;

    // Светлые иконки статус-бара только на тёмной ленте видео — раньше
    // после ухода с "Видео" они оставались белыми на светлой Главной.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0C0C0C) : AppColors.bg,
        body: _FadeIndexedStack(index: currentIndex, children: _pages),
        bottomNavigationBar: _BottomNav(
          items: _items,
          currentIndex: currentIndex,
          isDark: isDark,
          onTap: _onTap,
          onAddTap: _onAddTap,
        ),
      ),
    );
  }
}

// ── Cross-fading page container (keeps every page alive) ────────────────────────

class _FadeIndexedStack extends StatelessWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const _FadeIndexedStack({required this.index, required this.children})
    : duration = const Duration(milliseconds: 280);

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
              child: TickerMode(enabled: active, child: children[i]),
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
    Widget item(int i) => _NavItem(
      data: items[i],
      index: i,
      isActive: currentIndex == i,
      isDark: isDark,
      onTap: onTap,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0C0C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.hairline,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              item(0),
              item(1),
              Expanded(
                child: Center(
                  child: _AddButton(onTap: onAddTap, isDark: isDark),
                ),
              ),
              item(2),
              item(3),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Center add button (gradient squircle + press feedback + spin) ─────────────

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
    // градиент на чёрном фоне терял контраст с остальным UI ленты.
    final isDark = widget.isDark;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? 0.86 : 1.0,
        duration: Duration(milliseconds: _down ? 100 : 280),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: isDark ? null : AppColors.primaryGradient,
            color: isDark ? Colors.white : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isDark
                ? null
                : AppColors.glow(AppColors.primary, _down ? 0.5 : 0.38),
          ),
          child: AnimatedRotation(
            turns: _down ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: Icon(
              Icons.add_rounded,
              color: isDark ? const Color(0xFF0C0C0C) : Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav item (press feedback + active pill + indicator dot) ───────────────────

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

    final activeColor = isDark ? Colors.white : AppColors.primary;
    final inactiveColor = isDark ? Colors.white38 : const Color(0xFFA9A9BC);
    final activeHighlight = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.primary.withValues(alpha: 0.10);

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
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isActive ? 18 : 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive ? activeHighlight : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedScale(
                  scale: isActive ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    widget.data.icon,
                    size: 24,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
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
