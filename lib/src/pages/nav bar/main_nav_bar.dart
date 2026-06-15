import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MainNavBar extends StatefulWidget {
  const MainNavBar({Key? key}) : super(key: key);

  @override
  State<MainNavBar> createState() => _MainNavBarState();
}

class _MainNavBarState extends State<MainNavBar> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _PlaceholderPage(icon: Icons.home_rounded,     label: 'Главная'),
    const _PlaceholderPage(icon: Icons.search_rounded,   label: 'Поиск'),
    const _PlaceholderPage(icon: Icons.favorite_rounded, label: 'Избранное'),
    const _ProfilePage(),
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

// ── Bottom Nav ────────────────────────────────────────────────────────────────

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
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF2D1B6E).withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          items[i].icon,
                          size: 22,
                          color: isActive ? const Color(0xFF2D1B6E) : const Color(0xFFBBBBBB),
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? const Color(0xFF2D1B6E) : const Color(0xFFBBBBBB),
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

// ── Profile Page with logout ──────────────────────────────────────────────────

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Выйти из аккаунта?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
        content: const Text(
          'Вы уверены, что хотите выйти?',
          style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
        ),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFFEEEEEE)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Отмена', style: TextStyle(color: Color(0xFF1C1C1E))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Выйти', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      // AuthWrapper's StreamBuilder auto-redirects to SignIn
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
        ? user.displayName!
        : 'Без имени';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        title: const Text(
          'Профиль',
          style: TextStyle(
            color: Color(0xFF1C1C1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ── Avatar + name + email ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D1B6E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF2D1B6E), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1C1E),
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.email ?? 'Нет email',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9E9E9E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // ── Logout button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Выйти из аккаунта',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder pages ─────────────────────────────────────────────────────────

class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlaceholderPage({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        title: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1C1C1E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2D1B6E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF2D1B6E)),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Здесь будет страница «$label»',
              style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
            ),
          ],
        ),
      ),
    );
  }
}