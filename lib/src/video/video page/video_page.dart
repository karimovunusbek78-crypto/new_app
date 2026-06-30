import 'package:flutter/material.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/pages/home/widgets/car_photo_caursel.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class VideoPage extends StatelessWidget {
  const VideoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarsProvider>().carsWithVideo;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Видео',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: cars.isEmpty
          ? const _EmptyVideoState()
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
              itemCount: cars.length,
              separatorBuilder: (_, __) => SizedBox(height: 2.h),
              itemBuilder: (context, index) => _VideoCard(car: cars[index]),
            ),
    );
  }
}

class _EmptyVideoState extends StatelessWidget {
  const _EmptyVideoState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18.w,
            height: 18.w,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_circle_fill_rounded,
              size: 7.h,
              color: const Color(0xFFAEAEB2),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Пока нет видео',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Видеообзоры авто появятся здесь',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFF8E8E93),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final Car car;
  const _VideoCard({required this.car});

  @override
  Widget build(BuildContext context) {
    final liked = context.watch<FavoritesProvider>().isFavorite(car);

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
            Stack(
              alignment: Alignment.center,
              children: [
                CarPhotoCarousel(
                  photoPaths: car.photoPaths,
                  height: 28,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4.5.w),
                    topRight: Radius.circular(4.5.w),
                  ),
                ),
                // Indicates this listing has a video. Tap opens full info —
                // actual inline playback needs the video_player package.
                Container(
                  width: 9.w,
                  height: 9.w,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 4.h),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(3.5.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.name,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 0.3.h),
                  Text(
                    '${car.year} · ${car.price}',
                    style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93)),
                  ),
                  SizedBox(height: 1.2.h),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.read<FavoritesProvider>().toggleFavorite(car),
                        child: Row(
                          children: [
                            Icon(
                              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: liked ? Colors.red : Colors.black,
                              size: 2.4.h,
                            ),
                            SizedBox(width: 1.2.w),
                            Text('Нравится', style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Icon(Icons.mode_comment_outlined, color: const Color(0xFFB0B0B0), size: 2.4.h),
                      SizedBox(width: 1.2.w),
                      Text('Комментарии', style: TextStyle(fontSize: 11.5.sp, color: const Color(0xFFB0B0B0))),
                      const Spacer(),
                      Icon(Icons.share_outlined, color: const Color(0xFFB0B0B0), size: 2.4.h),
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