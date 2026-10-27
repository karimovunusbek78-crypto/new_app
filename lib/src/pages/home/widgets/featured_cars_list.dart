// lib/widgets/featured_cars_list.dart
import 'package:flutter/material.dart';
import 'package:new_app/src/app/ui_kit.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/home/widgets/home_car_card.dart';
import 'package:provider/provider.dart';

class FeaturedCarsList extends StatelessWidget {
  /// Сколько объявлений показывать прямо на Главной. Раньше рендерились
  /// ВСЕ объявления разом в Column (без ленивой подгрузки) — при большом
  /// числе машин Главная заметно тормозила. Остальные — по кнопке "Все".
  static const int homeLimit = 6;

  const FeaturedCarsList({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CarsProvider>();
    final cars = provider.cars;

    if (provider.isLoading) return const _CarsSkeleton();

    if (cars.isEmpty) {
      return const EmptyState(
        icon: Icons.directions_car_outlined,
        title: 'Пока нет объявлений',
        subtitle: 'Станьте первым — нажмите «+» внизу,\nчтобы продать авто',
      );
    }

    final visible = cars.take(homeLimit).toList();

    return Column(
      children: [
        SectionHeader(
          title: 'Свежие объявления',
          actionLabel: cars.length > homeLimit ? 'Все ${cars.length}' : null,
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllCarsPage()),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (int i = 0; i < visible.length; i++) ...[
                FadeSlideIn(
                  key: ValueKey(visible[i].id),
                  delay: FadeSlideIn.stagger(i, stepMs: 80),
                  child: _card(context, visible[i]),
                ),
                if (i != visible.length - 1) const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

Widget _card(BuildContext context, Car car) => HomeCarCard(
  car: car,
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => CarDetailPage(car: car)),
  ),
);

/// Полный список объявлений (ленивый, для кнопки "Все").
class AllCarsPage extends StatelessWidget {
  const AllCarsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarsProvider>().cars;
    return Scaffold(
      appBar: AppBar(title: Text('Все объявления · ${cars.length}')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        itemCount: cars.length,
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (context, i) => FadeSlideIn(
          delay: FadeSlideIn.stagger(i),
          child: _card(context, cars[i]),
        ),
      ),
    );
  }
}

class _CarsSkeleton extends StatelessWidget {
  const _CarsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 180, height: 22),
            const SizedBox(height: 14),
            for (int i = 0; i < 2; i++) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                ),
                padding: const EdgeInsets.only(bottom: 16),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 210, radius: 26),
                    SizedBox(height: 14),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 200, height: 18),
                          SizedBox(height: 8),
                          SkeletonBox(width: 140, height: 14),
                          SizedBox(height: 14),
                          SkeletonBox(height: 56, radius: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}
