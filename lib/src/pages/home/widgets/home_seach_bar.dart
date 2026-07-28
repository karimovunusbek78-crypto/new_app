import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class HomeSearchBar extends StatelessWidget {
  final VoidCallback? onTap;

  const HomeSearchBar({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: GestureDetector(
        onTap: onTap,
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
              Icon(Icons.search, color: const Color(0xFF8E8E93), size: 2.4.h),
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
    );
  }
}