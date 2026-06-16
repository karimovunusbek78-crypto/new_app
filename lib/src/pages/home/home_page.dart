import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class HomePage extends StatelessWidget {
  final VoidCallback? onSearchTap;

  const HomePage({super.key, this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
            ? user.displayName!
            : 'Пользователь';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Шапка ────────────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Доброе утро',
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
                    Stack(
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
                    ),
                  ],
                ),
              ),

              // ── Строка поиска ─────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.w),
                child: GestureDetector(
                  onTap: onSearchTap,
                  child: Container(
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3.5.w),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 3.5.w),
                        Icon(Icons.search,
                            color: const Color(0xFF8E8E93), size: 2.4.h),
                        SizedBox(width: 2.5.w),
                        Text(
                          'Поиск авто, марок или моделей...',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: const Color(0xFFAEAEB2),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 2.5.h),

              // ── Баннер ────────────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.w),
                child: Container(
                  height: 22.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF12121E),
                    borderRadius: BorderRadius.circular(5.w),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Car image covers the right ~65% of the banner
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: 65.w,
                        child: Image.network(
                          'https://images.unsplash.com/photo-1617531653332-bd46c16f4d68?w=900&q=85',
                          fit: BoxFit.cover,
                          alignment: Alignment.centerRight,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                      // Dark gradient: strong on left, fades to transparent on right
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                const Color(0xFF12121E),
                                const Color(0xFF12121E).withOpacity(0.92),
                                const Color(0xFF12121E).withOpacity(0.5),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.35, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Text + button — left side
                      Positioned(
                        left: 5.w,
                        top: 0,
                        bottom: 0,
                        width: 55.w,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'BMW M4',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Competition 2025',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 0.8.h),
                            Text(
                              'Мощь встречает точность.\nСоздан побеждать.',
                              style: TextStyle(
                                color: const Color(0xFFAEAEB2),
                                fontSize: 11.5.sp,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: 1.5.h),
                            ElevatedButton.icon(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3A6FF8),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 4.w, vertical: 1.1.h),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(2.5.w)),
                                elevation: 0,
                              ),
                              icon: Text(
                                'Подробнее',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.sp),
                              ),
                              label: Icon(Icons.arrow_forward, size: 2.h),
                            ),
                          ],
                        ),
                      ),
                      // Dot indicators
                      Positioned(
                        bottom: 1.2.h,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            return Container(
                              margin: EdgeInsets.symmetric(horizontal: 1.w),
                              width: i == 0 ? 4.w : 1.5.w,
                              height: 0.6.h,
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(1.w),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 3.h),

              // ── Категории ─────────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Категории',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3A6FF8),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('Все',
                          style: TextStyle(
                              fontSize: 14.sp, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 1.5.h),

              SizedBox(
                height: 13.h,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 5.w),
                  children: [
                    _CategoryCard(label: 'Седан', icon: Icons.directions_car),
                    SizedBox(width: 3.w),
                    _CategoryCard(
                        label: 'Внедорожник',
                        icon: Icons.directions_car_filled),
                    SizedBox(width: 3.w),
                    _CategoryCard(label: 'Электро', icon: Icons.electric_bolt),
                    SizedBox(width: 3.w),
                    _CategoryCard(
                        label: 'Спорт', icon: Icons.sports_motorsports),
                  ],
                ),
              ),

              SizedBox(height: 3.h),

              // ── Популярные авто ───────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Популярные авто',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3A6FF8),
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('Все',
                          style: TextStyle(
                              fontSize: 14.sp, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 1.5.h),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.w),
                child: Column(
                  children: const [
                    _FeaturedCarCard(
                      name: 'BMW M4',
                      year: '2025',
                      km: '12 500 км',
                      price: '65 000 \$',
                      transmission: 'Автомат',
                    ),
                    SizedBox(height: 12),
                    _FeaturedCarCard(
                      name: 'Audi RS7',
                      year: '2024',
                      km: '8 300 км',
                      price: '79 000 \$',
                      transmission: 'Автомат',
                    ),
                  ],
                ),
              ),

              SizedBox(height: 3.h),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Карточка категории ─────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;

  const _CategoryCard({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 3.2.h, color: const Color(0xFF1C1C1E)),
          SizedBox(height: 0.8.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Карточка авто ──────────────────────────────────────────────────────────────

class _FeaturedCarCard extends StatefulWidget {
  final String name;
  final String year;
  final String km;
  final String price;
  final String transmission;

  const _FeaturedCarCard({
    required this.name,
    required this.year,
    required this.km,
    required this.price,
    required this.transmission,
  });

  @override
  State<_FeaturedCarCard> createState() => _FeaturedCarCardState();
}

class _FeaturedCarCardState extends State<_FeaturedCarCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 24.w,
            height: 9.h,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(3.w),
            ),
            child: Icon(
              Icons.directions_car,
              size: 4.h,
              color: const Color(0xFFAEAEB2),
            ),
          ),
          SizedBox(width: 3.5.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  '${widget.year} • ${widget.km}',
                  style: TextStyle(
                      fontSize: 12.sp, color: const Color(0xFF8E8E93)),
                ),
                SizedBox(height: 0.6.h),
                Text(
                  widget.price,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3A6FF8),
                  ),
                ),
                SizedBox(height: 0.6.h),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 2.5.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  child: Text(
                    widget.transmission,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: const Color(0xFF636366),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _liked = !_liked),
            child: Icon(
              _liked ? Icons.favorite : Icons.favorite_border,
              color:
                  _liked ? const Color(0xFF3A6FF8) : const Color(0xFF8E8E93),
              size: 2.5.h,
            ),
          ),
        ],
      ),
    );
  }
}