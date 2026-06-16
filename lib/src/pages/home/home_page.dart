import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_app/src/pages/home/widgets/autasalon_list.dart';
import 'package:new_app/src/pages/home/widgets/home_seach_bar.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

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