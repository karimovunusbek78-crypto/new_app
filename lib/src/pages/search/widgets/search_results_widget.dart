import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/widgets/featured_cars_list.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class SearchResultsWidget extends StatelessWidget {
  final List<Car> results;

  const SearchResultsWidget({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off,
                  size: 6.h, color: const Color(0xFFAEAEB2)),
              SizedBox(height: 2.h),
              Text(
                'Ничего не найдено',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'Попробуйте изменить запрос или диапазон цен',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.sp, color: const Color(0xFF8E8E93)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 3.h),
      itemCount: results.length,
      separatorBuilder: (_, __) => SizedBox(height: 1.5.h),
      itemBuilder: (context, index) => FeaturedCarCard(car: results[index]),
    );
  }
}