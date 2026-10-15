import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class CarCategory {
  final String label;
  final IconData icon;
  const CarCategory(this.label, this.icon);
}

class CategoryGridWidget extends StatelessWidget {
  final List<CarCategory> categories;
  final ValueChanged<String> onSelect;

  const CategoryGridWidget({
    super.key,
    required this.categories,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 4.w,
          crossAxisSpacing: 5.w,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return GestureDetector(
            onTap: () => onSelect(cat.label),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.w),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(cat.icon,
                      size: 2.8.h, color: const Color(0xFF3A6FF8)),
                  SizedBox(height: 0.8.h),
                  Text(
                    cat.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}