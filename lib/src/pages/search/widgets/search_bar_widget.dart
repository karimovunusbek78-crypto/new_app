import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final ValueChanged<String> onSubmitted;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 1.5.h),
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
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (_) => onChanged(),
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                style: TextStyle(
                    fontSize: 14.sp, color: const Color(0xFF1C1C1E)),
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: 'Поиск авто, марок или моделей...',
                  hintStyle: TextStyle(
                      fontSize: 14.sp, color: const Color(0xFFAEAEB2)),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged();
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                  child: Icon(Icons.close,
                      color: const Color(0xFF8E8E93), size: 2.2.h),
                ),
              ),
          ],
        ),
      ),
    );
  }
}