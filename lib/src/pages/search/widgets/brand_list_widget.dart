import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class CarBrand {
  final String name;
  final String logoPath;
  const CarBrand(this.name, this.logoPath);
}

class BrandListWidget extends StatelessWidget {
  final List<CarBrand> brands;
  final ValueChanged<String> onSelect;

  const BrandListWidget({
    super.key,
    required this.brands,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 11.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 5.w),
        itemCount: brands.length,
        separatorBuilder: (_, __) => SizedBox(width: 4.w),
        itemBuilder: (context, index) {
          final brand = brands[index];
          return GestureDetector(
            onTap: () => onSelect(brand.name),
            child: Column(
              children: [
                Container(
                  width: 9.h,
                  height: 7.h,
                  padding: EdgeInsets.all(1.2.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    brand.logoPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        brand.name.substring(0, 1),
                        style: TextStyle(
                          fontSize: 40.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 0.8.h),
                Text(
                  brand.name,
                  style: TextStyle(
                      fontSize: 11.sp, color: const Color(0xFF1C1C1E)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}