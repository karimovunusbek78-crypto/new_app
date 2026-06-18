
// ── Пустое состояние ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class EmptyState extends StatelessWidget {
  const EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18.w,
            height: 18.w,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: 7.h,
              color: const Color(0xFFAEAEB2),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Нет избранных авто',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Нажмите ♡ на карточке авто,\nчтобы добавить в избранное',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFF8E8E93),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
