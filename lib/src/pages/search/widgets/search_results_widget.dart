import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_app/src/app/app_theme.dart';
import 'package:new_app/src/app/ui_kit.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/home/widgets/home_car_card.dart';
import 'package:new_app/src/video/controller/main_tab_controller.dart';

class SearchResultsWidget extends StatelessWidget {
  final List<Car> results;
  final bool videoGrid;

  const SearchResultsWidget({
    super.key,
    required this.results,
    required this.videoGrid,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Ничего не найдено',
            subtitle: 'Попробуйте изменить запрос\nили ослабить фильтры',
          ),
        ),
      );
    }

    // Фильтр "Только видео" — показываем ТОЛЬКО сами ролики (превью + плей),
    // без полной карточки объявления. Тап переключает нижний таб на "Видео"
    // (а не пушит отдельный экран) — так нижний navbar остаётся на месте,
    // и кнопка "поиск" внутри ленты корректно возвращает сюда же.
    if (videoGrid) {
      return GridView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: results.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.62,
        ),
        itemBuilder: (context, i) => FadeSlideIn(
          delay: FadeSlideIn.stagger(i, stepMs: 35),
          child: _VideoTile(car: results[i]),
        ),
      );
    }

    // "Всё" — полная карточка объявления, как на Главной.
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, i) => FadeSlideIn(
        delay: FadeSlideIn.stagger(i),
        child: HomeCarCard(
          car: results[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CarDetailPage(car: results[i])),
          ),
        ),
      ),
    );
  }
}

/// Компактный тайл видео (как сетка в TikTok/Reels): просто превью +
/// иконка плей поверх. НЕ показывает цену/спеки — только сам ролик.
///
/// ВАЖНО: тап НЕ делает Navigator.push(VideoPage(...)) — это создавало
/// отдельный full-screen роут без нижнего navbar. Вместо этого —
/// переключаем таб через NavTabController.openVideoFeed.
class _VideoTile extends StatelessWidget {
  final Car car;
  const _VideoTile({required this.car});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () =>
          context.read<NavTabController>().openVideoFeed(carId: car.id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.remove_red_eye_rounded,
                        color: Colors.white70,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        compactNumber(car.viewsCount),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
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

  Widget _thumb() {
    if (car.photoPaths.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: car.photoPaths.first,
        fit: BoxFit.cover,
        memCacheWidth: 300,
        placeholder: (_, __) => Container(color: AppColors.surfaceAlt),
        errorWidget: (_, __, ___) => Container(color: Colors.black26),
      );
    }
    return Container(color: Colors.black26);
  }
}
