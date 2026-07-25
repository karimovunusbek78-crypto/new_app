import 'dart:io';
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/favorite/proget/tag.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:new_app/src/pages/saved/provider/saved_cars_provider.dart';
import 'package:new_app/src/video/video.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class SavedCarCard extends StatelessWidget {
  final Car car;
  const SavedCarCard({required this.car, Key? key}) : super(key: key);

  // Жёлтая закладка «сохранено» — тот же цвет, что и в видеоленте
  // (_saveYellow в video_page.dart), чтобы всё было единообразно.
  static const _saveYellow = Color(0xFFFFD60A);

  Widget _image(String path, {BoxFit fit = BoxFit.cover}) {
    Widget fallback() => Container(
          color: const Color(0xFFE5E5EA),
          child: Center(
            child: Icon(Icons.directions_car_rounded,
                size: 7.h, color: const Color(0xFFC7C7CC)),
          ),
        );
    if (path.startsWith('http')) {
      return Image.network(path,
          fit: fit, errorBuilder: (_, __, ___) => fallback());
    }
    final isFile = path.startsWith('/') || File(path).existsSync();
    if (isFile) {
      return Image.file(File(path),
          fit: fit, errorBuilder: (_, __, ___) => fallback());
    }
    return Image.asset(path, fit: fit, errorBuilder: (_, __, ___) => fallback());
  }

  bool get _hasVideo => car.videoPath != null && car.videoPath!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<SavedCarsProvider>().isSaved(car.id);
    final photos = car.photoPaths;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CarDetailPage(car: car)),
      ),
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
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4.5.w),
                topRight: Radius.circular(4.5.w),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 15.h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: const Color(0xFFE5E5EA)),
                    if (photos.isNotEmpty)
                      _image(photos.first)
                    else
                      Center(
                        child: Icon(Icons.directions_car_rounded,
                            size: 7.h, color: const Color(0xFFC7C7CC)),
                      ),
                    Positioned(
                      top: 1.2.h,
                      left: 3.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 2.5.w, vertical: 0.5.h),
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
                    if (_hasVideo)
                      Positioned(
                        bottom: 1.2.h,
                        left: 3.w,
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoPage(initialCarId: car.id),
                            ),
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 2.2.w, vertical: 0.5.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(2.h),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded,
                                    size: 1.8.h, color: Colors.white),
                                SizedBox(width: 0.5.w),
                                Text(
                                  'Видео',
                                  style: TextStyle(
                                    fontSize: 10.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 0.8.h,
                      right: 2.5.w,
                      child: GestureDetector(
                        onTap: () =>
                            context.read<SavedCarsProvider>().toggleSaved(car),
                        child: Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            // Жёлтая (как в ленте), когда сохранено.
                            color: saved
                                ? _saveYellow
                                : const Color(0xFF8E8E93),
                            size: 2.2.h,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                              style: TextStyle(
                                  fontSize: 12.sp, color: const Color(0xFF8E8E93)),
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
                      Tag(text: car.transmission, icon: Icons.settings_rounded),
                      Tag(text: car.engineCapacity, icon: Icons.speed_rounded),
                      Tag(text: car.bodyType, icon: Icons.directions_car_rounded),
                      Tag(text: car.color, icon: Icons.circle_rounded),
                    ],
                  ),
                  SizedBox(height: 1.2.h),
                  const Divider(color: Color(0xFFF2F2F7), thickness: 1),
                  SizedBox(height: 0.8.h),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 1.8.h, color: const Color(0xFF8E8E93)),
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