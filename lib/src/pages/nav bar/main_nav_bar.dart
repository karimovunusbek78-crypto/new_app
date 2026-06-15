import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:new_app/src/pages/favorite/favorite_page.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:new_app/src/pages/profile/profile_page.dart';

class MainNavBar extends StatefulWidget {
  const MainNavBar({Key? key}) : super(key: key);

  @override
  State<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends State<MainNavBar> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
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

  void _onTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_currentIndex],
      bottomNavigationBar: _BottomNav(
        items: _items,
        currentIndex: _currentIndex,
        onTap: _onTap,
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

  const _BottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            children: List.generate(items.length, (i) {
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
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
                          items[i].icon,
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
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? const Color.fromARGB(255, 6, 3, 19)
                              : const Color(0xFFBBBBBB),
                        ),
                        child: Text(items[i].label),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}