import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:new_app/src/app/app_theme.dart';
import 'package:new_app/src/app/ui_kit.dart';

import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/pages/home/widgets/autasalon_list.dart';
import 'package:new_app/src/pages/home/widgets/home_seach_bar.dart';
import 'package:new_app/src/video/video%20page/profile/autosalon_stats_page.dart';
import 'package:new_app/src/video/video%20page/profile/user_stats_page.dart';
import 'widgets/home_header.dart';
import 'widgets/home_banner.dart';
import 'widgets/featured_cars_list.dart';

class HomePage extends StatelessWidget {
  final VoidCallback? onSearchTap;
  const HomePage({super.key, this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    // Каждая секция появляется с небольшой задержкой — "лесенкой".
    Widget section(int i, Widget child) =>
        FadeSlideIn(delay: FadeSlideIn.stagger(i, stepMs: 90), child: child);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              section(0, const HomeHeader()),
              section(1, HomeSearchBar(onTap: onSearchTap)),
              const SizedBox(height: 22),
              section(2, const HomeBanner()),
              const SizedBox(height: 26),
              section(3, const _MyAutosalonEntryCard()),
              section(3, const _MyPublicationsEntryCard()),
              section(4, const AutosalonList()),
              section(5, const FeaturedCarsList()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Раньше здесь была секция «Мои объявления» с горизонтальным списком
/// карточек публикаций прямо на HomePage. Теперь публикации на самой
/// главной не показываются — вместо них маленькая карточка-переход
/// «Мой профиль публикаций», которая открывает UserStatsPage(uid: uid)
/// (там уже и сетка публикаций, и статистика).
class _MyPublicationsEntryCard extends StatelessWidget {
  const _MyPublicationsEntryCard();

  void _openMyProfile(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserStatsPage(uid: uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    // Считаем количество объявлений только для маленькой подписи
    // на карточке — сам список публикаций здесь больше не строится.
    final myCarsCount = context.watch<CarsProvider>().myCars(uid).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Pressable(
        onTap: () => _openMyProfile(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppColors.softShadow(),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Мои публикации',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      myCarsCount > 0
                          ? '$myCarsCount объявлений · статистика'
                          : 'Ваши объявления и статистика',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.inkSoft, size: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Крупная карточка-переход «Мой автосалон» — репутация владельца.
///
/// Показывается ТОЛЬКО если у текущего пользователя реально есть
/// опубликованный автосалон — т.е. существует документ
/// autosalons/{uid} (id документа = uid владельца, как и в
/// AutosalonStatsPage._isOwner). Если салона нет — виджет схлопывается
/// в SizedBox.shrink().
///
/// Светлая карточка в стиле остального приложения (белый фон, тонкая
/// синяя рамка-акцент как у AutosalonCard) — но крупнее и с бейджем
/// «Владелец», плюс строка с живой статистикой (кол-во авто, суммарные
/// просмотры и лайки по всем машинам салона), которая считается на
/// лету из коллекции cars по автосалону.
class _MyAutosalonEntryCard extends StatelessWidget {
  const _MyAutosalonEntryCard();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('autosalons')
          .doc(uid)
          .snapshots(),
      builder: (context, salonSnap) {
        final salon = salonSnap.data?.data();
        // У пользователя нет своего автосалона — карточку не показываем.
        if (salon == null) return const SizedBox.shrink();

        final name = (salon['name'] as String?)?.trim();
        final tagline = (salon['tagline'] as String?)?.trim();
        final logoUrl = salon['logoUrl'] as String?;
        final hasLogo = logoUrl != null && logoUrl.isNotEmpty;

        // Живая статистика по всем машинам этого автосалона — считается
        // на лету из уже загруженного CarsProvider (без отдельного
        // Firestore-запроса), чтобы не зависеть от рассинхрона
        // кешированного carsCount на документе.
        final salonCars = context
            .watch<CarsProvider>()
            .cars
            .where((c) => c.autosalonId == uid)
            .toList();
        final totalViews =
            salonCars.fold<int>(0, (acc, c) => acc + c.viewsCount);
        final totalLikes =
            salonCars.fold<int>(0, (acc, c) => acc + c.likesCount);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Pressable(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AutosalonStatsPage(salonId: uid),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.darkGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: AppColors.softShadow(0.18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          image: hasLogo
                              ? DecorationImage(
                                  image: NetworkImage(logoUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: hasLogo
                            ? null
                            : const Icon(Icons.storefront_rounded,
                                color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    (name != null && name.isNotEmpty)
                                        ? name
                                        : 'Мой автосалон',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Владелец',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              (tagline != null && tagline.isNotEmpty)
                                  ? tagline
                                  : 'Статистика и репутация вашего салона',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 16),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _statItem(
                        icon: Icons.directions_car_rounded,
                        value: '${salonCars.length}',
                        label: 'авто',
                      ),
                      const SizedBox(width: 10),
                      _statItem(
                        icon: Icons.visibility_rounded,
                        value: compactNumber(totalViews),
                        label: 'просмотров',
                      ),
                      const SizedBox(width: 10),
                      _statItem(
                        icon: Icons.favorite_rounded,
                        value: compactNumber(totalLikes),
                        label: 'лайков',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: const Color(0xFF9D92FF)),
                const SizedBox(width: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
