import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/widgets/autasalon_list.dart';
import 'package:new_app/src/pages/home/widgets/home_seach_bar.dart';
import 'package:new_app/src/pages/home/pages/my_stats_page.dart';
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
              const _MyCarsSection(),
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

class _MyCarsSection extends StatelessWidget {
  const _MyCarsSection();

  void _openStats(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyStatsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final myCars = context.watch<CarsProvider>().myCars(uid);
    if (myCars.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 3.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openStats(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Мои объявления',
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.w800, color: Colors.black),
                  ),
                  Row(
                    children: [
                      Text(
                        'Статистика',
                        style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF8A8A90)),
                      ),
                      SizedBox(width: 1.w),
                      Icon(Icons.chevron_right_rounded,
                          size: 2.2.h, color: const Color(0xFF8A8A90)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 1.5.h),
          SizedBox(
            height: 25.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              itemCount: myCars.length,
              separatorBuilder: (_, __) => SizedBox(width: 3.w),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _openStats(context),
                child: _MyCarCard(car: myCars[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyCarCard extends StatelessWidget {
  final Car car;
  const _MyCarCard({required this.car});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4.w)),
            child: Container(
              height: 13.h,
              width: double.infinity,
              color: Colors.black,
              child: car.videoPath != null && car.videoPath!.isNotEmpty
                  ? const Center(
                      child: Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 32),
                    )
                  : (car.photoPaths.isNotEmpty
                      ? Image.network(car.photoPaths.first, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.black12))
                      : const Center(
                          child: Icon(Icons.directions_car_outlined,
                              color: Colors.white38, size: 28))),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(2.5.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 0.8.h),
                Row(
                  children: [
                    const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
                    SizedBox(width: 1.w),
                    Text('${car.likesCount}', style: TextStyle(fontSize: 10.5.sp)),
                    SizedBox(width: 3.w),
                    const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.grey),
                    SizedBox(width: 1.w),
                    Text('${car.viewsCount}', style: TextStyle(fontSize: 10.5.sp)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}