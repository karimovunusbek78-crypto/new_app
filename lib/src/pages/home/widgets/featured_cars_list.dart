// lib/widgets/featured_cars_list.dart
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/favorite/providers/favorites_provider.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../models/car.dart';

class FeaturedCarsList extends StatelessWidget {
  const FeaturedCarsList({super.key});

  static final List<Car> _cars = [
    const Car(
      id: '1',
      name: 'BMW M4',
      year: '2025',
      km: '12 500 км',
      price: '65 000 \$',
      transmission: 'Автомат',
      fuelType: 'Бензин',
      engineCapacity: '3.0 л',
      bodyType: 'Купе',
      color: 'Чёрный',
      location: 'Бишкек',
    ),
    const Car(
      id: '2',
      name: 'Audi RS7',
      year: '2024',
      km: '8 300 км',
      price: '79 000 \$',
      transmission: 'Автомат',
      fuelType: 'Бензин',
      engineCapacity: '4.0 л',
      bodyType: 'Седан',
      color: 'Серый',
      location: 'Алматы',
    ),
  ];

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
              for (int i = 0; i < _cars.length; i++) ...[
                FeaturedCarCard(car: _cars[i]),
                if (i != _cars.length - 1) SizedBox(height: 1.5.h),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class FeaturedCarCard extends StatelessWidget {
  final Car car;

  const FeaturedCarCard({super.key, required this.car});

  @override
  Widget build(BuildContext context) {
    final liked = context.watch<FavoritesProvider>().isFavorite(car);

    return Container(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24.w,
            height: 9.h,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(3.w),
            ),
            child: Icon(
              Icons.directions_car,
              size: 4.h,
              color: const Color(0xFFAEAEB2),
            ),
          ),
          SizedBox(width: 3.5.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car.name,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  '${car.year} • ${car.km}',
                  style: TextStyle(
                      fontSize: 12.sp, color: const Color(0xFF8E8E93)),
                ),
                SizedBox(height: 0.6.h),
                Text(
                  car.price,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3A6FF8),
                  ),
                ),
                SizedBox(height: 0.8.h),
                Wrap(
                  spacing: 1.5.w,
                  runSpacing: 0.8.h,
                  children: [
                    _InfoTag(text: car.transmission),
                    _InfoTag(text: car.fuelType),
                    _InfoTag(text: car.engineCapacity),
                    _InfoTag(text: car.bodyType),
                  ],
                ),
                SizedBox(height: 0.8.h),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 1.8.h, color: const Color(0xFF8E8E93)),
                    SizedBox(width: 1.w),
                    Text(
                      '${car.location} • ${car.color}',
                      style: TextStyle(
                          fontSize: 11.sp, color: const Color(0xFF8E8E93)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.read<FavoritesProvider>().toggleFavorite(car),
            child: Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              color: liked ? Colors.black : const Color(0xFF8E8E93),
              size: 2.5.h,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final String text;
  const _InfoTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(2.w),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.sp,
          color: const Color(0xFF636366),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}