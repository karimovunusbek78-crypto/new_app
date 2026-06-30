import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/widgets/car_photo_caursel.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class HomeCarCard extends StatelessWidget {
  final Car car;
  final VoidCallback? onTap;
  const HomeCarCard({super.key, required this.car, this.onTap});

  @override
  Widget build(BuildContext context) {
    final liked = context.watch<FavoritesProvider>().isFavorite(car);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.5.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CarPhotoCarousel(
                  photoPaths: car.photoPaths,
                  height: 15,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4.5.w),
                    topRight: Radius.circular(4.5.w),
                  ),
                ),
                Positioned(
                  top: 1.2.h,
                  left: 3.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Text(
                      car.fuelType,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3A6FF8),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0.8.h,
                  right: 2.5.w,
                  child: GestureDetector(
                    onTap: () => context.read<FavoritesProvider>().toggleFavorite(car),
                    child: Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: liked ? Colors.red : const Color(0xFF8E8E93),
                        size: 2.2.h,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(3.5.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              car.name,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1C1C1E),
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 0.4.h),
                            Text(
                              '${car.year} · ${car.km}',
                              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93)),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        car.price,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3A6FF8),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.2.h),
                  Wrap(
                    spacing: 1.5.w,
                    runSpacing: 0.8.h,
                    children: [
                      _Tag(text: car.transmission, icon: Icons.settings_rounded),
                      _Tag(text: car.engineCapacity, icon: Icons.speed_rounded),
                      _Tag(text: car.bodyType, icon: Icons.directions_car_rounded),
                      _Tag(text: car.color, icon: Icons.circle_rounded),
                    ],
                  ),
                  SizedBox(height: 1.2.h),
                  const Divider(color: Color(0xFFF2F2F7), thickness: 1),
                  SizedBox(height: 0.8.h),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 1.8.h, color: const Color(0xFF8E8E93)),
                      SizedBox(width: 1.w),
                      Text(
                        car.location,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF8E8E93),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Tag({required this.text, required this.icon});

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