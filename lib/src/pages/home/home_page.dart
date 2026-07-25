import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/pages/home/widgets/autasalon_list.dart';
import 'package:new_app/src/pages/home/widgets/home_seach_bar.dart';
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