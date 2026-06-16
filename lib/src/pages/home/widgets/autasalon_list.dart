import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class AutosalonList extends StatelessWidget {
  const AutosalonList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Автосалоны',
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
        SizedBox(
          height: 16.h,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            children: [
              const AutosalonCard(
                name: 'Бишкек Моторс',
                location: 'Бишкек, пр. Чуй',
                rating: 4.8,
                carsCount: 32,
                color: Color(0xFF3A6FF8),
              ),
              SizedBox(width: 3.w),
              const AutosalonCard(
                name: 'АвтоЛюкс',
                location: 'Бишкек, ул. Ахунбаева',
                rating: 4.6,
                carsCount: 21,
                color: Color(0xFFE17055),
              ),
              SizedBox(width: 3.w),
              const AutosalonCard(
                name: 'Drive City',
                location: 'Бишкек, ул. Боконбаева',
                rating: 4.9,
                carsCount: 47,
                color: Color(0xFF00B894),
              ),
              SizedBox(width: 3.w),
              const AutosalonCard(
                name: 'Premium Auto Group',
                location: 'Бишкек, пр. Манаса',
                rating: 4.7,
                carsCount: 18,
                color: Color(0xFF6C5CE7),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AutosalonCard extends StatelessWidget {
  final String name;
  final String location;
  final double rating;
  final int carsCount;
  final Color color;

  const AutosalonCard({
    super.key,
    required this.name,
    required this.location,
    required this.rating,
    required this.carsCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46.w,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9.w,
                height: 9.w,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(2.5.w),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.store, color: color, size: 2.4.h),
              ),
              SizedBox(width: 2.5.w),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.2.h),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 1.7.h, color: const Color(0xFF8E8E93)),
              SizedBox(width: 1.w),
              Expanded(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.sp, color: const Color(0xFF8E8E93)),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Row(
            children: [
              Icon(Icons.star_rounded,
                  size: 2.h, color: const Color(0xFFFFB400)),
              SizedBox(width: 0.6.w),
              Text(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 2.2.w, vertical: 0.4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Text(
                  '$carsCount авто',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF636366),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}