// lib/widgets/home_car_card.dart
import 'package:flutter/material.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/models/car.dart';


/// Карточка авто: фото-карусель сверху (с точками-индикаторами, как в
/// CarPhotoCarousel), затем название, теги характеристик и цена.
/// Без бейджа «Проверен», без рейтинга и без кнопки «В корзину».
class HomeCarCard extends StatelessWidget {
  final Car car;
  final VoidCallback? onTap;

  /// Тап по иконке графика в углу фото — например, открыть аналитику
  /// по этому объявлению/видео. Необязательный.
  final VoidCallback? onStatsTap;

  const HomeCarCard({
    super.key,
    required this.car,
    this.onTap,
    this.onStatsTap,
  });

  // Текст стал темнее и контрастнее по всей карточке — вторичный серый
  // (_grey) раньше был почти нечитаемым (0xFF8E8E93), теперь ощутимо
  // темнее (0xFF5B5B60), а основной чёрный (_ink) — почти настоящий
  // чёрный вместо тёмно-серого.
  static const _ink = Color(0xFF0A0A0B);
  static const _grey = Color(0xFF5B5B60);
  static const _accent = Color(0xFF2F5FE0);
  static const _hair = Color(0xFFE8E8EB);

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
    // Единый источник правды для лайков — CarsProvider, тот же, что и в
    // видео-ленте, на странице деталей и в «Избранном».
    final liked = context.watch<CarsProvider>().isLikedByMe(car.id);

    // Доп. инфо строкой — привод и состояние, если заполнены; количество
    // владельцев в теги, если тоже заполнено.
    final extraLine = [
      if (car.driveType.trim().isNotEmpty) car.driveType,
      if (car.condition.trim().isNotEmpty) car.condition,
      if (car.color.trim().isNotEmpty) car.color,
    ].join(' · ');

    return GestureDetector(
      onTap: onTap,
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
            // CarPhotoCarousel уже рисует точки-индикаторы снизу сама —
            // здесь просто оборачиваем в Stack, чтобы добавить сердечко
            // и иконку статистики поверх.
            Stack(
              children: [
                CarPhotoCarousel(
                  photoPaths: car.photoPaths,
                  height: 26,
                  borderRadius: BorderRadius.zero,
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

                // Иконка графика/статистики
                if (onStatsTap != null)
                  Positioned(
                    top: 1.6.h + 9.5.w + 1.2.h,
                    right: 3.w,
                    child: _circleIcon(
                      icon: Icons.bar_chart_rounded,
                      onTap: onStatsTap!,
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
                      _chip(Icons.local_gas_station_outlined, car.fuelType),
                      _chip(Icons.settings_outlined, car.transmission),
                      _chip(Icons.directions_car_filled_outlined, car.engineCapacity),
                      if (car.ownersCount.trim().isNotEmpty)
                        _chip(Icons.badge_outlined, '${car.ownersCount} влад.'),
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