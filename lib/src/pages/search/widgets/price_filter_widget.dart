import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class PriceFilterWidget extends StatelessWidget {
  final TextEditingController minController;
  final TextEditingController maxController;
  final VoidCallback onChanged;
  final VoidCallback onClear;

  const PriceFilterWidget({
    super.key,
    required this.minController,
    required this.maxController,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasPriceFilter =
        minController.text.isNotEmpty || maxController.text.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 1.5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PriceField(
              controller: minController,
              label: 'Цена от',
              hint: '0',
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: _PriceField(
              controller: maxController,
              label: 'Цена до',
              hint: '100 000',
              onChanged: onChanged,
            ),
          ),
          if (hasPriceFilter) ...[
            SizedBox(width: 2.5.w),
            GestureDetector(
              onTap: onClear,
              child: Container(
                width: 6.h,
                height: 6.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.close,
                    size: 2.2.h, color: const Color(0xFF8E8E93)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onChanged;

  const _PriceField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 1.w, bottom: 0.6.h),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8E8E93),
            ),
          ),
        ),
        Container(
          height: 6.h,
          padding: EdgeInsets.symmetric(horizontal: 3.5.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3.w),
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
              Icon(Icons.attach_money,
                  size: 2.h, color: const Color(0xFF3A6FF8)),
              SizedBox(width: 1.w),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFAEAEB2),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}