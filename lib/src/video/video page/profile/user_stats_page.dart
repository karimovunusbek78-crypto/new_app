import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/pages/home/providers/subscribtion_provider.dart';

/// Публичная страница профиля/статистики продавца.
/// Открывается при тапе на аватар/имя автора в видео-ленте.
///
/// Показывает:
///  • имя и аватар автора (живой стрим из users/{uid});
///  • подписчиков / всего лайков / кол-во публикаций;
///  • список публикаций с аналитикой (лайки, просмотры, за сегодня);
///  • кнопку «Подписаться», если это чужой профиль.
///
/// Работает и для своего uid (тогда кнопки подписки нет) — на неё же
/// ведёт кнопка «Аналитика» на собственных видео.
class UserStatsPage extends StatelessWidget {
  final String uid;
  const UserStatsPage({super.key, required this.uid});

  static const _accent = Color(0xFF111111);
  static const _grey = Color(0xFF9A9AA0);

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarsProvider>().myCars(uid);
    final totalLikes = cars.fold<int>(0, (sum, c) => sum + c.likesCount);
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = myUid != null && myUid == uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() as Map<String, dynamic>?;
            final name = ((data?['name'] as String?) ?? '').trim();
            final avatarUrl = ((data?['avatarUrl'] as String?) ?? '').trim();
            final subscribers = data?['subscribersCount'] ?? 0;

            return Column(
              children: [
                // ── Шапка с кнопкой назад ────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(5.w, 0.5.h, 5.w, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.only(right: 3.w),
                          child: Icon(Icons.arrow_back,
                              color: _accent, size: 3.2.h),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          isMe ? 'Моя аналитика' : 'Профиль продавца',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: _accent,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 3.h),
                    children: [
                      _ProfileHeader(
                        name: name.isNotEmpty ? name : 'Автор',
                        avatarUrl: avatarUrl,
                        showSubscribe: !isMe,
                        uid: uid,
                      ),
                      SizedBox(height: 2.5.h),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.people_alt_outlined,
                              value: '$subscribers',
                              label: 'Подписчики',
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.favorite_rounded,
                              value: '$totalLikes',
                              label: 'Всего лайков',
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.local_offer_outlined,
                              value: '${cars.length}',
                              label: 'Опубликовано',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Публикации',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: _accent,
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      if (cars.isEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 4.h),
                          child: Center(
                            child: Text(
                              'Пока нет объявлений',
                              style: TextStyle(fontSize: 13.sp, color: _grey),
                            ),
                          ),
                        )
                      else
                        ...cars.map((c) => _CarAnalyticsRow(car: c)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Шапка профиля: аватар, имя, подписка ──────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final bool showSubscribe;
  final String uid;

  const _ProfileHeader({
    required this.name,
    required this.avatarUrl,
    required this.showSubscribe,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final subs = context.watch<SubscriptionsProvider>();
    final subscribed = subs.isSubscribed(uid);
    final pending = subs.isPending(uid);
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Container(
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: Row(
        children: [
          Container(
            width: 14.w,
            height: 14.w,
            decoration: BoxDecoration(
              color: Colors.black12,
              shape: BoxShape.circle,
              image: avatarUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: avatarUrl.isEmpty
                ? Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.black54,
                      ),
                    ),
                  )
                : null,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111111),
              ),
            ),
          ),
          if (showSubscribe) ...[
            SizedBox(width: 2.w),
            GestureDetector(
              onTap: pending
                  ? null
                  : () => context
                      .read<SubscriptionsProvider>()
                      .toggleSubscribe(uid),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.9.h),
                decoration: BoxDecoration(
                  color: subscribed ? Colors.white : Colors.black,
                  borderRadius: BorderRadius.circular(6.w),
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                child: Text(
                  subscribed ? 'Вы подписаны' : 'Подписаться',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: subscribed ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCard(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 2.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF111111), size: 2.6.h),
          SizedBox(height: 1.h),
          Text(
            value,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 0.3.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9.5.sp, color: const Color(0xFF9A9AA0)),
          ),
        ],
      ),
    );
  }
}

// ── Строка объявления с аналитикой (без удаления — публичный вид) ─────
class _CarAnalyticsRow extends StatelessWidget {
  final Car car;
  const _CarAnalyticsRow({required this.car});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CarDetailPage(car: car)),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 2.5.w),
        padding: EdgeInsets.all(2.5.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFEFEFEF)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3.w),
              child: SizedBox(
                width: 15.w,
                height: 15.w,
                child: car.photoPaths.isNotEmpty
                    ? Image.network(
                        car.photoPaths.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.black12),
                      )
                    : Container(
                        color: Colors.black12,
                        child: const Icon(Icons.directions_car_outlined,
                            color: Colors.black38),
                      ),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 0.7.h),
                  Row(
                    children: [
                      const Icon(Icons.favorite,
                          size: 14, color: Colors.redAccent),
                      SizedBox(width: 1.w),
                      Text('${car.likesCount}',
                          style: TextStyle(fontSize: 10.5.sp)),
                      SizedBox(width: 3.w),
                      const Icon(Icons.remove_red_eye_outlined,
                          size: 14, color: Colors.grey),
                      SizedBox(width: 1.w),
                      Text('${car.viewsCount}',
                          style: TextStyle(fontSize: 10.5.sp)),
                      SizedBox(width: 3.w),
                      FutureBuilder<int>(
                        future:
                            context.read<CarsProvider>().viewsToday(car.id),
                        builder: (context, snap) {
                          final today = snap.data ?? 0;
                          return Row(
                            children: [
                              const Icon(Icons.today_outlined,
                                  size: 14, color: Colors.blueGrey),
                              SizedBox(width: 1.w),
                              Text('$today сегодня',
                                  style: TextStyle(fontSize: 10.5.sp)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: const Color(0xFF8A8A90), size: 2.6.h),
          ],
        ),
      ),
    );
  }
}