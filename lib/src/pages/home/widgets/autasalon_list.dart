import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:new_app/src/app/app_theme.dart';
import 'package:new_app/src/app/ui_kit.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/video/video%20page/profile/autosalon_stats_page.dart';
import 'package:provider/provider.dart';

class AutosalonList extends StatelessWidget {
  const AutosalonList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('autosalons')
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const _AutosalonSkeleton();
        }
        final docs = snap.data?.docs ?? const [];
        // Ничего не публиковали ещё — секцию просто не показываем.
        if (docs.isEmpty) return const SizedBox.shrink();

        // Кол-во авто считаем по живому списку объявлений, а не по полю
        // carsCount в документе салона: оно перезаписывалось числом авто
        // из ПОСЛЕДНЕЙ публикации (0 при редактировании профиля) и врало.
        final cars = context.watch<CarsProvider>().cars;
        int countFor(String salonId) =>
            cars.where((c) => c.autosalonId == salonId).length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Автосалоны'),
              const SizedBox(height: 14),
              SizedBox(
                height: 208,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final photos = (d['photoUrls'] as List?)?.cast<String>();
                    return FadeSlideIn(
                      delay: FadeSlideIn.stagger(i, stepMs: 70),
                      offset: const Offset(30, 0),
                      child: AutosalonCard(
                        salonId: docs[i].id,
                        name: (d['name'] as String?)?.trim().isNotEmpty == true
                            ? d['name']
                            : 'Автосалон',
                        subtitle: _subtitle(d),
                        carsCount: countFor(docs[i].id),
                        logoUrl: d['logoUrl'] as String?,
                        coverUrl: (photos != null && photos.isNotEmpty)
                            ? photos.first
                            : null,
                        locationsCount:
                            (d['locationsCount'] as num?)?.toInt() ?? 0,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _subtitle(Map<String, dynamic> d) {
    final tagline = (d['tagline'] as String?)?.trim();
    if (tagline != null && tagline.isNotEmpty) return tagline;
    final years = (d['yearsOnMarket'] as String?)?.trim();
    if (years != null && years.isNotEmpty) return '$years лет на рынке';
    return 'Официальный дилер';
  }
}

class AutosalonCard extends StatelessWidget {
  final String salonId;
  final String name;
  final String subtitle;
  final int carsCount;
  final String? logoUrl;
  final String? coverUrl;
  final int locationsCount;

  const AutosalonCard({
    super.key,
    required this.salonId,
    required this.name,
    required this.subtitle,
    required this.carsCount,
    this.logoUrl,
    this.coverUrl,
    this.locationsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    final hasCover = coverUrl != null && coverUrl!.isNotEmpty;

    return Pressable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AutosalonStatsPage(salonId: salonId)),
      ),
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.softShadow(),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Обложка: фото салона или фирменный градиент
            SizedBox(
              height: 96,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasCover)
                    CachedNetworkImage(
                      imageUrl: coverUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 600,
                      errorWidget: (_, __, ___) => const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.darkGradient,
                        ),
                      ),
                    )
                  else
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.directions_car_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$carsCount авто',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -22),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: AppColors.softShadow(0.12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: hasLogo
                            ? CachedNetworkImage(
                                imageUrl: logoUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 150,
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.storefront_rounded,
                                  color: AppColors.primary,
                                ),
                              )
                            : Container(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: AppColors.blue,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            locationsCount > 0
                                ? '$subtitle · $locationsCount ${_plural(locationsCount)}'
                                : subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _plural(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'филиал';
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'филиала';
    return 'филиалов';
  }
}

class _AutosalonSkeleton extends StatelessWidget {
  const _AutosalonSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 140, height: 22),
            const SizedBox(height: 14),
            Row(
              children: const [
                SkeletonBox(width: 250, height: 190, radius: 24),
                SizedBox(width: 14),
                Expanded(child: SkeletonBox(height: 190, radius: 24)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
