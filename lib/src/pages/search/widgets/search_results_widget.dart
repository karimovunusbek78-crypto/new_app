import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/home/widgets/home_car_card.dart';
import 'package:new_app/src/video/controller/main_tab_controller.dart';
import '../search_page.dart' show ResultFilter;

class SearchResultsWidget extends StatelessWidget {
  final List<Car> results;
  final ResultFilter filter;

  const SearchResultsWidget({
    super.key,
    required this.results,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const _EmptyResults();

    // Фильтр "Только видео" — показываем ТОЛЬКО сами ролики (превью + плей),
    // без полной карточки объявления. Тап переключает нижний таб на "Видео"
    // (а не пушит отдельный экран) — так нижний navbar остаётся на месте,
    // и кнопка "поиск" внутри ленты корректно возвращает сюда же.
    if (filter == ResultFilter.video) {
      return GridView.builder(
        padding: EdgeInsets.all(3.5.w),
        itemCount: results.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2.w,
          mainAxisSpacing: 2.w,
          childAspectRatio: 0.62,
        ),
        itemBuilder: (context, i) => _VideoTile(car: results[i]),
      );
    }

    // "Всё" — полная карточка объявления, как на Главной.
    return ListView.separated(
      padding: EdgeInsets.all(3.5.w),
      itemCount: results.length,
      separatorBuilder: (_, __) => SizedBox(height: 2.h),
      itemBuilder: (context, i) => _ListingCard(car: results[i]),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 8.h, color: Colors.black26),
          SizedBox(height: 2.h),
          Text(
            'Ничего не найдено',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

/// Компактный тайл видео (как сетка в TikTok/Reels): просто превью +
/// иконка плей поверх. НЕ показывает цену/спеки — только сам ролик.
///
/// ВАЖНО: тап НЕ делает Navigator.push(VideoPage(...)) — это создавало
/// отдельный full-screen роут без нижнего navbar (VideoPage пушенный
/// напрямую не имеет своего bottomNavigationBar) и ломало кнопку "поиск"
/// внутри ленты (она дёргала NavTabController, который управляет ДРУГИМ,
/// уже скрытым под пушенным роутом, экраном MainNavBar).
///
/// Вместо этого — переключаем таб через NavTabController.openVideoFeed:
/// MainNavBar остаётся на экране (navbar виден), лента (уже живущая
/// внутри MainNavBar) сама прыгает на нужное авто, а кнопка "поиск"
/// внутри неё (setIndex(1)) корректно возвращает обратно на этот же
/// экран поиска.
class _VideoTile extends StatelessWidget {
  final Car car;
  const _VideoTile({required this.car});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.read<NavTabController>().openVideoFeed(carId: car.id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.5.w),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _thumb(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.45),
                  ],
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            Positioned(
              left: 1.5.w,
              right: 1.5.w,
              bottom: 1.h,
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye_rounded,
                      color: Colors.white, size: 12),
                  SizedBox(width: 1.w),
                  Expanded(
                    child: Text(
                      _fmtCount(car.viewsCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb() {
    if (car.photoPaths.isNotEmpty) {
      return Image.network(
        car.photoPaths.first,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.black26),
      );
    }
    return Container(color: Colors.black26);
  }

  String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) {
      final v = n / 1000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}K';
    }
    return '$n';
  }
}

/// Полная карточка объявления (та же, что и на Главной) — фото,
/// цена, теги, локация. Тап -> страница деталей авто.
class _ListingCard extends StatelessWidget {
  final Car car;
  const _ListingCard({required this.car});

  @override
  Widget build(BuildContext context) {
    return HomeCarCard(
      car: car,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CarDetailPage(car: car)),
      ),
    );
  }
}