import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:new_app/src/pages/favorite/favorite_page.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:new_app/src/pages/profile/profile_page.dart';
import 'package:new_app/src/pages/add/add_page.dart';

class MainNavBar extends StatefulWidget {
  const MainNavBar({Key? key}) : super(key: key);

  @override
  State<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends State<MainNavBar> {
  int _currentIndex = 0;

  void _onTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  void _onAddTap() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPage()),
    );
  }

  /// Pages list — HomePage receives a callback to switch to the Search tab.
  List<Widget> get _pages => [
        HomePage(onSearchTap: () => _onTap(1)),
        const SearchPage(),
        const FavoritePage(),
        const ProfilePage(),
      ];

  final List<_NavItemData> _items = const [
    _NavItemData(icon: Icons.home_rounded,     label: 'Главная'),
    _NavItemData(icon: Icons.search_rounded,   label: 'Поиск'),
    _NavItemData(icon: Icons.favorite_rounded, label: 'Избранное'),
    _NavItemData(icon: Icons.person_rounded,   label: 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_currentIndex],
      bottomNavigationBar: _BottomNav(
        items: _items,
        currentIndex: _currentIndex,
        onTap: _onTap,
        onAddTap: _onAddTap,
      ),
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
                  _navItem(items[0], 0),
                  _navItem(items[1], 1),
                  SizedBox(width: 18.w),
                  _navItem(items[2], 2),
                  _navItem(items[3], 3),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -0.7.h,
          child: GestureDetector(
            onTap: onAddTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 6.h,
              height: 6.h,
              decoration: BoxDecoration(
                color: const Color(0xFF2D1B6E),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2D1B6E).withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 3.2.h,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _navItem(_NavItemData item, int index) {
    final isActive = index == currentIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
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
                item.icon,
                size: 2.8.h,
                color: isActive
                    ? const Color.fromARGB(255, 5, 2, 19)
                    : const Color(0xFFBBBBBB),
              ),
            ),
            SizedBox(height: 0.4.h),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? const Color.fromARGB(255, 6, 3, 19)
                    : const Color(0xFFBBBBBB),
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}