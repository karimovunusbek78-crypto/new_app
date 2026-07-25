import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/pages/home/providers/subscribtion_provider.dart';

/// Публичная страница профиля/статистики продавца — в стиле канала YouTube.
/// Открывается при тапе на аватар/имя автора в видео-ленте, а также
/// теперь используется как «Моя статистика» — при переходе со своим
/// собственным uid (кнопка «Статистика»/карточки на HomePage), заменив
/// отдельную MyStatsPage.
///
/// Показывает:
///  • баннер + аватар + имя автора (живой стрим из users/{uid});
///  • подписчиков / всего просмотров / кол-во публикаций одной строкой;
///  • кнопку «Подписаться» в стиле YouTube, если это чужой профиль;
///  • для СВОЕГО профиля — вместо кнопки подписки показывается пилюля-
///    бейдж «Мой профиль публикаций», просто обозначающая, что это
///    ваша собственная страница (без счётчика лайков, как было раньше);
///  • сетку публикаций с аналитикой (лайки, просмотры, за сегодня).
///
/// ФИКСЫ:
///  • Стрелка «назад» раньше жила ВНУТРИ _ChannelHeader (SliverToBoxAdapter)
///    и поэтому уезжала вверх вместе с контентом при скролле. Теперь она
///    вынесена в отдельный Positioned поверх CustomScrollView — не зависит
///    от скролла, всегда на экране.
///  • Список раньше использовал BouncingScrollPhysics — это давало эффект
///    "оттягивания" контента вниз, когда уже находишься в самом верху.
///    Заменено на ClampingScrollPhysics — скролл жёстко останавливается
///    на границах, без пружинного оттягивания.
class UserStatsPage extends StatelessWidget {
  final String uid;
  const UserStatsPage({super.key, required this.uid});

  static const _ink = Color(0xFF0F0F0F);
  static const _grey = Color(0xFF6B6B70);
  static const _hair = Color(0xFFECECEE);
  static const _bg = Color(0xFFF7F7F8);

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarsProvider>().myCars(uid);
    final totalLikes = cars.fold<int>(0, (sum, c) => sum + c.likesCount);
    final totalViews = cars.fold<int>(0, (sum, c) => sum + c.viewsCount);
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = myUid != null && myUid == uid;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data() as Map<String, dynamic>?;
              final name = ((data?['name'] as String?) ?? '').trim();
              final avatarUrl = ((data?['avatarUrl'] as String?) ?? '').trim();
              final subscribers = (data?['subscribersCount'] ?? 0) as num;

              return CustomScrollView(
                // ClampingScrollPhysics: без пружинного оттягивания вниз,
                // когда уже находишься в самом верху списка (был bounce
                // из-за BouncingScrollPhysics — типичный iOS-эффект, но
                // здесь он не нужен).
                physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: _ChannelHeader(
                      name: name.isNotEmpty ? name : 'Автор',
                      avatarUrl: avatarUrl,
                      subscribers: subscribers.toInt(),
                      publications: cars.length,
                      totalLikes: totalLikes,
                      totalViews: totalViews,
                      showSubscribe: !isMe,
                      isMe: isMe,
                      uid: uid,
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SectionHeaderDelegate(count: cars.length),
                  ),
                  if (cars.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 6.h, bottom: 6.h),
                        child: Column(
                          children: [
                            Icon(Icons.video_library_outlined,
                                size: 5.h, color: const Color(0xFFC8C8CC)),
                            SizedBox(height: 1.5.h),
                            Text(
                              'Пока нет объявлений',
                              style:
                                  TextStyle(fontSize: 12.5.sp, color: _grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 3.w,
                          mainAxisSpacing: 2.5.h,
                          // Высота карточки не зависит от текста — картинка
                          // сама сжимается (Expanded), поэтому переполнение
                          // снизу больше не может произойти при любом
                          // соотношении сторон экрана.
                          childAspectRatio: 0.66,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _VideoCard(car: cars[i]),
                          childCount: cars.length,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: 2.h + bottomSafe),
                  ),
                ],
              );
            },
          ),

          // Стрелка «назад» — фиксированный оверлей поверх скролла, не
          // является частью контента и поэтому никогда не уезжает вверх.
          Positioned(
            top: 0,
            left: 3.w,
            right: 3.w,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 6.h,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.all(1.6.w),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Заголовок секции «Публикации», приклеивается при скролле ──────────
class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int count;
  const _SectionHeaderDelegate({required this.count});

  static const _ink = Color(0xFF0F0F0F);
  static const _grey = Color(0xFF6B6B70);
  static const _hair = Color(0xFFECECEE);

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF7F7F8),
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: Row(
        children: [
          Icon(Icons.grid_view_rounded, size: 2.h, color: _ink),
          SizedBox(width: 2.w),
          Text(
            'Публикации',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          SizedBox(width: 2.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.2.w, vertical: 0.3.h),
            decoration: BoxDecoration(
              color: _hair,
              borderRadius: BorderRadius.circular(5.w),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
                color: _grey,
              ),
            ),
          ),
          const Spacer(),
          Container(height: 1, color: Colors.transparent),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) =>
      oldDelegate.count != count;
}

// ── Шапка канала: баннер, аватар, имя, статистика, подписка ───────────
// ВАЖНО: стрелка «назад» здесь больше НЕ рисуется — она вынесена в
// отдельный Positioned-оверлей в UserStatsPage.build, чтобы не скроллилась
// вместе с баннером.
class _ChannelHeader extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final int subscribers;
  final int publications;
  final int totalLikes;
  final int totalViews;
  final bool showSubscribe;
  final bool isMe;
  final String uid;

  const _ChannelHeader({
    required this.name,
    required this.avatarUrl,
    required this.subscribers,
    required this.publications,
    required this.totalLikes,
    required this.totalViews,
    required this.showSubscribe,
    required this.isMe,
    required this.uid,
  });

  static const _ink = Color(0xFF0F0F0F);
  static const _grey = Color(0xFF6B6B70);

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final avatarSize = 22.w.clamp(72.0, 110.0);

    return Column(
      children: [
        SizedBox(
          height: 14.h + avatarSize / 2,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 14.h,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1C1C1E), Color(0xFF3A3A3C)],
                    ),
                  ),
                  child: Opacity(
                    opacity: 0.10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.8, -0.6),
                          radius: 1.3,
                          colors: [Colors.white, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 14.h - avatarSize / 2,
                child: Center(
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        shape: BoxShape.circle,
                        image: avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(avatarUrl),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: avatarUrl.isEmpty
                          ? Center(
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black54,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 1.4.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(height: 0.8.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Text(
            '${_formatCount(subscribers)} подписчиков  •  '
            '$publications публикаций  •  '
            '${_formatCount(totalViews)} просмотров',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.8.sp,
              color: _grey,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
        SizedBox(height: 1.8.h),
        // Чужой профиль → обычная кнопка «Подписаться» (YouTube-style).
        // Свой профиль → вместо кнопки подписки/счётчика лайков теперь
        // просто пилюля-бейдж, обозначающая, что это ваша собственная
        // страница публикаций (замена прежней MyStatsPage-шапки).
        if (showSubscribe)
          _SubscribeButton(uid: uid)
        else if (isMe)
          const _MyProfileBadge(),
        SizedBox(height: 1.6.h),
        const Divider(height: 1, thickness: 1, color: Color(0xFFECECEE)),
      ],
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ── Бейдж «Мой профиль публикаций» — заменяет счётчик лайков на
// собственном профиле. Не кликабельный, чисто информационный, в том же
// пилюльном стиле, что и кнопка подписки, но нейтрального серого цвета.
class _MyProfileBadge extends StatelessWidget {
  const _MyProfileBadge();

  static const _ink = Color(0xFF0F0F0F);
  static const _hair = Color(0xFFECECEE);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.1.h),
      decoration: BoxDecoration(
        color: _hair,
        borderRadius: BorderRadius.circular(8.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_pin_circle_outlined, size: 2.h, color: _ink),
          SizedBox(width: 1.5.w),
          Text(
            'Мой профиль публикаций',
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Кнопка подписки в стиле YouTube (красная пилюля / серая «подписаны») ─
class _SubscribeButton extends StatelessWidget {
  final String uid;
  const _SubscribeButton({required this.uid});

  static const _red = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    final subs = context.watch<SubscriptionsProvider>();
    final subscribed = subs.isSubscribed(uid);
    final pending = subs.isPending(uid);

    return GestureDetector(
      onTap: pending
          ? null
          : () => context.read<SubscriptionsProvider>().toggleSubscribe(uid),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: BoxConstraints(minWidth: 34.w),
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.3.h),
        decoration: BoxDecoration(
          color: subscribed ? const Color(0xFFF0F0F1) : _red,
          borderRadius: BorderRadius.circular(8.w),
        ),
        child: pending
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: subscribed ? Colors.black45 : Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    subscribed
                        ? Icons.notifications_none_rounded
                        : Icons.add_rounded,
                    size: 18,
                    color: subscribed ? const Color(0xFF0F0F0F) : Colors.white,
                  ),
                  SizedBox(width: 1.3.w),
                  Text(
                    subscribed ? 'Вы подписаны' : 'Подписаться',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color:
                          subscribed ? const Color(0xFF0F0F0F) : Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Карточка публикации в сетке — превью в стиле YouTube ──────────────
// ВАЖНО: картинка обёрнута в Expanded, а не в AspectRatio, поэтому вся
// карточка всегда точно помещается в ячейку грида — переполнение снизу
// (RenderFlex overflow) больше невозможно ни при каком childAspectRatio
// и ни при какой ширине экрана.
class _VideoCard extends StatelessWidget {
  final Car car;
  const _VideoCard({required this.car});

  static const _ink = Color(0xFF0F0F0F);
  static const _grey = Color(0xFF6B6B70);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CarDetailPage(car: car)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3.5.w),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  car.photoPaths.isNotEmpty
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
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 40,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x99000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye_rounded,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          '${car.viewsCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: FutureBuilder<int>(
                      future: context.read<CarsProvider>().viewsToday(car.id),
                      builder: (context, snap) {
                        final today = snap.data ?? 0;
                        if (today <= 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '+$today сегодня',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 0.8.h),
          Text(
            car.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: _ink,
              height: 1.2,
            ),
          ),
          SizedBox(height: 0.4.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_rounded,
                  size: 12, color: Color(0xFFFF3B30)),
              const SizedBox(width: 3),
              Text('${car.likesCount}',
                  style: TextStyle(fontSize: 9.5.sp, color: _grey)),
            ],
          ),
        ],
      ),
    );
  }
}