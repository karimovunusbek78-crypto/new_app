// ── Карточка авто (избранное) ────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/video/video.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

// adjust to real path

/// Карточка авто в списке избранного — тот же стиль, что и HomeCarCard:
/// фото-карусель с точками-индикаторами сверху, тёмный контрастный текст,
/// теги характеристик и локация. Без бейджа «Проверен», без рейтинга и
/// без кнопки «В корзину».
class FavoriteCarCard extends StatelessWidget {
  final Car car;
  const FavoriteCarCard({required this.car, Key? key}) : super(key: key);

  static const _ink = Color(0xFF0A0A0B);
  static const _grey = Color(0xFF5B5B60);
  static const _accent = Color(0xFF2F5FE0);
  static const _hair = Color(0xFFE8E8EB);

  bool get _hasVideo => car.videoPath != null && car.videoPath!.isNotEmpty;

  Widget _chip(IconData icon, String label) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.8.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F3),
        borderRadius: BorderRadius.circular(2.5.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 1.8.h, color: _ink),
          SizedBox(width: 1.3.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIcon({required IconData icon, required VoidCallback onTap, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 9.5.w,
        height: 9.5.w,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6),
          ],
        ),
        child: Icon(icon, color: color ?? _ink, size: 2.2.h),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Единый источник правды для лайков — CarsProvider, тот же, что и
    // в видео-ленте, на Home и на странице деталей.
    final liked = context.watch<CarsProvider>().isLikedByMe(car.id);

    final extraLine = [
      if (car.driveType.trim().isNotEmpty) car.driveType,
      if (car.condition.trim().isNotEmpty) car.condition,
      if (car.color.trim().isNotEmpty) car.color,
    ].join(' · ');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CarDetailPage(car: car)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5.5.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Фото-карусель ──
            Stack(
              children: [
                CarPhotoCarousel(
                  photoPaths: car.photoPaths,
                  height: 26,
                  borderRadius: BorderRadius.zero,
                ),

                // Бейдж топлива — сохранён с прежней карточки
                if (car.fuelType.trim().isNotEmpty)
                  Positioned(
                    top: 1.6.h,
                    left: 3.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.94),
                        borderRadius: BorderRadius.circular(2.5.w),
                      ),
                      child: Text(
                        car.fuelType,
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                        ),
                      ),
                    ),
                  ),

                // Бейдж "есть видео" — открывает ленту сразу на этом авто
                if (_hasVideo)
                  Positioned(
                    bottom: 1.6.h,
                    left: 3.w,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPage(initialCarId: car.id),
                        ),
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 2.6.w, vertical: 0.8.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(2.h),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 1.9.h, color: Colors.white),
                            SizedBox(width: 0.6.w),
                            Text(
                              'Видео',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Сердечко избранного
                Positioned(
                  top: 1.6.h,
                  right: 3.w,
                  child: _circleIcon(
                    icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: liked ? Colors.redAccent : _ink,
                    onTap: () => context.read<CarsProvider>().toggleLike(car.id),
                  ),
                ),
              ],
            ),

            // ── Контент ──
            Padding(
              padding: EdgeInsets.fromLTRB(4.2.w, 2.h, 4.2.w, 2.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              car.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17.5.sp,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              '${car.bodyType} · ${car.year} год',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: _grey,
                              ),
                            ),
                            if (extraLine.isNotEmpty) ...[
                              SizedBox(height: 0.3.h),
                              Text(
                                extraLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        car.price,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: _accent,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 1.6.h),

                  // Теги характеристик
                  Wrap(
                    spacing: 1.8.w,
                    runSpacing: 1.h,
                    children: [
                      _chip(Icons.speed_outlined, car.km),
                      _chip(Icons.settings_outlined, car.transmission),
                      _chip(Icons.directions_car_filled_outlined, car.engineCapacity),
                      _chip(Icons.circle, car.color),
                    ],
                  ),

                  SizedBox(height: 1.7.h),
                  Divider(height: 1, color: _hair),
                  SizedBox(height: 1.5.h),

                  // Локация
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 2.h, color: _ink),
                      SizedBox(width: 1.w),
                      Expanded(
                        child: Text(
                          car.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
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