import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class RecentSearchesWidget extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  const RecentSearchesWidget({
    super.key,
    required this.items,
    required this.onSelect,
    required this.onRemove,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Недавние запросы',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              TextButton(
                onPressed: onClearAll,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3A6FF8),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Очистить',
                  style: TextStyle(
                      fontSize: 13.sp, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.2.h),
          Wrap(
            spacing: 2.5.w,
            runSpacing: 1.2.h,
            children: items.map((term) {
              return GestureDetector(
                onTap: () => onSelect(term),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 3.5.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.w),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history,
                          size: 1.9.h, color: const Color(0xFF8E8E93)),
                      SizedBox(width: 1.5.w),
                      Text(
                        term,
                        style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF1C1C1E)),
                      ),
                      SizedBox(width: 1.5.w),
                      GestureDetector(
                        onTap: () => onRemove(term),
                        child: Icon(Icons.close,
                            size: 1.7.h,
                            color: const Color(0xFFAEAEB2)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}