// lib/widgets/featured_cars_list.dart
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/home/widgets/home_car_card.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class FeaturedCarsList extends StatelessWidget {
  const FeaturedCarsList({super.key});

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarsProvider>().cars;

    if (cars.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
        child: Column(
          children: [
            Icon(Icons.directions_car_outlined,
                size: 5.h, color: const Color(0xFFC7C7CC)),
            SizedBox(height: 1.h),
            Text(
              'Пока нет объявлений',
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF8E8E93),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
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
            children: [
              for (int i = 0; i < cars.length; i++) ...[
                HomeCarCard(
                  car: cars[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CarDetailPage(car: cars[i])),
                  ),
                ),
                if (i != cars.length - 1) SizedBox(height: 1.5.h),
              ],
            ],
          ),
        ),
      ],
    );
  }
}