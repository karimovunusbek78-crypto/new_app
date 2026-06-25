import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class MainNavBar extends StatefulWidget {
  const MainNavBar({super.key});

  @override
  State<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends State<MainNavBar> {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(onSearchTap: () => _onTap(1)),
      const SearchPage(),
      const FavoritePage(),
      const ProfilePage(),
    ];
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  void _onAddTap() {
    HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPage()));
  }

  final List<_NavItemData> _items = const [
    _NavItemData(icon: Icons.home_rounded, label: 'Главная'),
    _NavItemData(icon: Icons.search_rounded, label: 'Поиск'),
    _NavItemData(icon: Icons.favorite_rounded, label: 'Избранное'),
    _NavItemData(icon: Icons.person_rounded, label: 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _FadeIndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _BottomNav(
        items: _items,
        currentIndex: _currentIndex,
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
          // A whisper of movement makes the fade feel intentional, not laggy.
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
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;

  const _BottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
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
                  _NavItem(
                    data: items[0],
                    index: 0,
                    isActive: currentIndex == 0,
                    onTap: onTap,
                  ),
                  _NavItem(
                    data: items[1],
                    index: 1,
                    isActive: currentIndex == 1,
                    onTap: onTap,
                  ),
                  SizedBox(width: 18.w),
                  _NavItem(
                    data: items[2],
                    index: 2,
                    isActive: currentIndex == 2,
                    onTap: onTap,
                  ),
                  _NavItem(
                    data: items[3],
                    index: 3,
                    isActive: currentIndex == 3,
                    onTap: onTap,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -0.7.h,
          child: _AddButton(onTap: onAddTap),
        ),
      ],
    );
  }
}

// ── Center add button (press feedback + playful spin) ──────────────────────────

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
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
            color: const Color(0xFF2D1B6E),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2D1B6E).withOpacity(_down ? 0.5 : 0.35),
                blurRadius: _down ? 18 : 12,
                offset: Offset(0, _down ? 6 : 4),
              ),
            ],
          ),
          child: AnimatedRotation(
            turns: _down ? 0.125 : 0.0, // 45° spin on press
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Icon(Icons.add_rounded, color: Colors.white, size: 3.2.h),
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
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.data,
    required this.index,
    required this.isActive,
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
                    color: isActive
                        ? const Color.fromARGB(255, 5, 2, 16).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(1.5.h),
                  ),
                  child: Icon(
                    widget.data.icon,
                    size: 2.8.h,
                    color: isActive
                        ? const Color.fromARGB(255, 5, 2, 19)
                        : const Color(0xFFBBBBBB),
                  ),
                ),
              ),
              SizedBox(height: 0.4.h),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? const Color.fromARGB(255, 6, 3, 19)
                      : const Color(0xFFBBBBBB),
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
