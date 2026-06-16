import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                          fontWeight: FontWeight.w600, fontSize: 13.sp),
                    ),
                    label: Icon(Icons.arrow_forward, size: 2.h),
                  ),
                ],
              ),
            ),
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
    );
  }
}