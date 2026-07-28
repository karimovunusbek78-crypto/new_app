
// ── Тег ──────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class Tag extends StatelessWidget {
  final String text;
  final IconData icon;
  const Tag({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(2.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 1.5.h, color: const Color(0xFF8E8E93)),
          SizedBox(width: 1.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF48484A),
            ),
          ),
        ],
      ),
    );
  }
}