import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

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
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
            ? user.displayName!
            : 'Пользователь';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeHeader(displayName: displayName),
              HomeSearchBar(onTap: onSearchTap),
              SizedBox(height: 2.5.h),
              const HomeBanner(),
              SizedBox(height: 3.h),
              const _MyAutosalonEntryCard(),
              const _MyPublicationsEntryCard(),
              const AutosalonList(),
              SizedBox(height: 3.h),
              const FeaturedCarsList(),
              SizedBox(height: 3.h),
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

  static const _ink = Color(0xFF111111);
  static const _grey = Color(0xFF8A8A90);

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
      padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 3.h),
      child: GestureDetector(
        onTap: () => _openMyProfile(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.w),
            border: Border.all(color: const Color(0xFFEFEFEF)),
          ),
          child: Row(
            children: [
              Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_pin_circle_outlined,
                    color: _ink, size: 2.6.h),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Мой профиль публикаций',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    SizedBox(height: 0.3.h),
                    Text(
                      myCarsCount > 0
                          ? '$myCarsCount объявлений · статистика'
                          : 'Ваши объявления и статистика',
                      style: TextStyle(fontSize: 10.5.sp, color: _grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _grey, size: 2.4.h),
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
/// Отличается от простой карточки-перехода: тёмный акцентный фон,
/// логотип покрупнее, бейдж «Владелец», и строка с живой статистикой
/// (кол-во авто, суммарные просмотры и лайки по всем машинам салона) —
/// считается на лету из коллекции cars по автосалону, а не берётся
/// только из закешированного carsCount на самом документе салона.
class _MyAutosalonEntryCard extends StatelessWidget {
  const _MyAutosalonEntryCard();

  static const _bg = Color(0xFF15130F);
  static const _accent = Color(0xFFE0A458);
  static const _grey = Color(0xFFB8B4AC);

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

        return Padding(
          padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 3.h),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AutosalonStatsPage(salonId: uid),
              ),
            ),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.5.w),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(5.w),
                boxShadow: [
                  BoxShadow(
                    color: _bg.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 13.w,
                        height: 13.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(3.5.w),
                          border: Border.all(
                              color: _accent.withOpacity(0.5), width: 1.2),
                          image: hasLogo
                              ? DecorationImage(
                                  image: NetworkImage(logoUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: hasLogo
                            ? null
                            : Icon(Icons.storefront_rounded,
                                color: _accent, size: 3.h),
                      ),
                      SizedBox(width: 3.5.w),
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
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 2.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 2.w, vertical: 0.3.h),
                                  decoration: BoxDecoration(
                                    color: _accent.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(1.5.w),
                                    border: Border.all(
                                        color: _accent.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    'Владелец',
                                    style: TextStyle(
                                      fontSize: 8.5.sp,
                                      fontWeight: FontWeight.w700,
                                      color: _accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 0.4.h),
                            Text(
                              (tagline != null && tagline.isNotEmpty)
                                  ? tagline
                                  : 'Статистика и репутация вашего салона',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.sp, color: _grey),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: _grey, size: 2.6.h),
                    ],
                  ),
                  SizedBox(height: 2.2.h),
                  Container(height: 1, color: Colors.white.withOpacity(0.08)),
                  SizedBox(height: 2.h),
                  // Живая статистика по всем машинам этого автосалона —
                  // считается на лету, чтобы не зависеть от возможного
                  // рассинхрона кешированного carsCount на документе.
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('cars')
                        .where('autosalonId', isEqualTo: uid)
                        .snapshots(),
                    builder: (context, carsSnap) {
                      final docs = carsSnap.data?.docs ?? const [];
                      final carsCount = docs.length;
                      int totalViews = 0;
                      int totalLikes = 0;
                      for (final doc in docs) {
                        final d = doc.data();
                        totalViews +=
                            (d['viewsCount'] as num?)?.toInt() ?? 0;
                        totalLikes +=
                            (d['likesCount'] as num?)?.toInt() ?? 0;
                      }
                      return Row(
                        children: [
                          _statItem(
                            icon: Icons.directions_car_rounded,
                            value: '$carsCount',
                            label: 'авто',
                          ),
                          _statDivider(),
                          _statItem(
                            icon: Icons.visibility_rounded,
                            value: _compactNumber(totalViews),
                            label: 'просмотров',
                          ),
                          _statDivider(),
                          _statItem(
                            icon: Icons.favorite_rounded,
                            value: _compactNumber(totalLikes),
                            label: 'лайков',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 5.h,
      color: Colors.white.withOpacity(0.08),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 1.7.h, color: _accent),
              SizedBox(width: 1.2.w),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 0.2.h),
          Text(
            label,
            style: TextStyle(fontSize: 9.5.sp, color: _grey),
          ),
        ],
      ),
    );
  }

  String _compactNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }
}