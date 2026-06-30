import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/widgets/car_photo_caursel.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class CarDetailPage extends StatelessWidget {
  final Car car;
  const CarDetailPage({super.key, required this.car});

  @override
  Widget build(BuildContext context) {
    final liked = context.watch<FavoritesProvider>().isFavorite(car);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: Colors.black, size: 3.h),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Информация об авто',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 3.h),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 2.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CarPhotoCarousel(photoPaths: car.photoPaths, height: 32),
                    Padding(
                      padding: EdgeInsets.all(4.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  car.name,
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Text(
                                car.priceNegotiable ? '${car.price} · торг' : car.price,
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF3A6FF8),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            '${car.year} год · ${car.km}',
                            style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8A8A8E)),
                          ),
                          SizedBox(height: 2.h),
                          _infoGrid(),
                          if (car.description.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            _sectionTitle('Описание'),
                            SizedBox(height: 0.8.h),
                            Text(
                              car.description,
                              style: TextStyle(fontSize: 13.5.sp, color: Colors.black87, height: 1.5),
                            ),
                          ],
                          if (car.changesDescription.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            _sectionTitle('Что было изменено'),
                            SizedBox(height: 0.8.h),
                            Text(
                              car.changesDescription,
                              style: TextStyle(fontSize: 13.5.sp, color: Colors.black87, height: 1.5),
                            ),
                          ],
                          SizedBox(height: 2.h),
                          _sectionTitle('Контакты'),
                          SizedBox(height: 0.8.h),
                          if (car.phone.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.phone_outlined, size: 2.h, color: const Color(0xFF8A8A8E)),
                                SizedBox(width: 2.w),
                                Text(car.phone, style: TextStyle(fontSize: 13.5.sp, color: Colors.black87)),
                              ],
                            ),
                          SizedBox(height: 0.8.h),
                          Row(
                            children: [
                              if (car.contactWhatsapp) _contactBadge('WhatsApp', Icons.chat_outlined),
                              if (car.contactWhatsapp && car.contactTelegram) SizedBox(width: 2.w),
                              if (car.contactTelegram) _contactBadge('Telegram', Icons.send_outlined),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Like / Comment / Share — like is functional, the rest is UI for now ──
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEFEFEF))),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.read<FavoritesProvider>().toggleFavorite(car),
                    child: Row(
                      children: [
                        Icon(
                          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: liked ? Colors.red : Colors.black,
                          size: 2.6.h,
                        ),
                        SizedBox(width: 1.5.w),
                        Text('Нравится', style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Row(
                    children: [
                      Icon(Icons.mode_comment_outlined, color: const Color(0xFFB0B0B0), size: 2.6.h),
                      SizedBox(width: 1.5.w),
                      Text('Комментарии', style: TextStyle(fontSize: 12.5.sp, color: const Color(0xFFB0B0B0))),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.share_outlined, color: const Color(0xFFB0B0B0), size: 2.6.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: Colors.black));

  Widget _contactBadge(String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(2.h),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 1.8.h, color: Colors.black),
          SizedBox(width: 1.5.w),
          Text(label, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _infoGrid() {
    final items = <MapEntry<String, String>>[
      MapEntry('Коробка', car.transmission),
      MapEntry('Топливо', car.fuelType),
      MapEntry('Объём', car.engineCapacity),
      MapEntry('Кузов', car.bodyType),
      MapEntry('Привод', car.driveType),
      MapEntry('Цвет', car.color),
      MapEntry('Состояние', car.condition),
      MapEntry('Владельцев', car.ownersCount),
      MapEntry('Город', car.location),
    ].where((e) => e.value.trim().isNotEmpty).toList();

    return Wrap(
      spacing: 2.w,
      runSpacing: 1.2.h,
      children: items
          .map(
            (e) => SizedBox(
              width: 42.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key, style: TextStyle(fontSize: 11.sp, color: const Color(0xFF8A8A8E))),
                  SizedBox(height: 0.3.h),
                  Text(
                    e.value,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.black),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}