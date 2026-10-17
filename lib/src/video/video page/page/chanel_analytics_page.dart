import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/video/video%20page/page/video_analytics_page.dart';

/// «Аналитика канала» — сводная статистика ПО ВСЕМ вашим публикациям
/// сразу, в отличие от VideoAnalyticsPage, которая показывает разбор
/// ОДНОГО конкретного видео.
///
/// Отвечает на вопрос «какие из моих видео вообще интересны людям»:
///  • сверху — сводка: публикаций, суммарные просмотры, суммарные лайки,
///    средний «интерес» (лайки/просмотры) по всем видео;
///  • ниже — список ВСЕХ видео, отсортированный по «интересу» (доле
///    лайков от просмотров) от самого залайканного к наименее;
///  • у каждого видео — ранг, превью, просмотры/лайки и горизонтальная
///    полоска интереса, нормализованная относительно лучшего видео в
///    списке (у лидера полоска всегда полная);
///  • тап по видео → VideoAnalyticsPage(car: car) — уже существующая
///    страница с детальной аналитикой этого конкретного ролика (кто
///    лайкнул, кто смотрел, просмотры за сегодня и т.д.).
class ChanelAnalyticsPage extends StatefulWidget {
  final String uid;
  const ChanelAnalyticsPage({Key? key, required this.uid}) : super(key: key);

  @override
  _ChanelAnalyticsPageState createState() => _ChanelAnalyticsPageState();
}

class _ChanelAnalyticsPageState extends State<ChanelAnalyticsPage> {
  static const _ink = Color(0xFF0F0F0F);
  static const _grey = Color(0xFF6B6B70);
  static const _hair = Color(0xFFECECEE);
  static const _bg = Color(0xFFF7F7F8);
  static const _accent = Color(0xFF3A6FF8);

  /// «Интерес» к конкретному видео: доля лайков от просмотров.
  /// Чем выше — тем охотнее аудитория, посмотревшая ролик, его лайкает.
  /// Просмотров ещё нет → интерес 0 (а не деление на ноль).
  double _engagement(Car c) =>
      c.viewsCount > 0 ? c.likesCount / c.viewsCount : 0.0;

  @override
  Widget build(BuildContext context) {
    final cars = context.watch<CarsProvider>().myCars(widget.uid);

    final totalViews = cars.fold<int>(0, (sum, c) => sum + c.viewsCount);
    final totalLikes = cars.fold<int>(0, (sum, c) => sum + c.likesCount);
    final avgEngagement = totalViews > 0 ? totalLikes / totalViews : 0.0;

    // Копия списка, отсортированная по интересу — от самого высокого к
    // самому низкому. Если интерес одинаковый (например, у обоих 0) —
    // выше тот, у кого больше просмотров, чтобы список не выглядел
    // случайным при отсутствии данных.
    final ranked = [...cars]..sort((a, b) {
        final cmp = _engagement(b).compareTo(_engagement(a));
        if (cmp != 0) return cmp;
        return b.viewsCount.compareTo(a.viewsCount);
      });
    final maxEngagement =
        ranked.isNotEmpty ? _engagement(ranked.first) : 0.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: cars.isEmpty
                  ? _emptyState()
                  : ListView(
                      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 3.h),
                      children: [
                        _summaryRow(
                          publications: cars.length,
                          totalViews: totalViews,
                          totalLikes: totalLikes,
                          avgEngagement: avgEngagement,
                        ),
                        SizedBox(height: 2.5.h),
                        Text(
                          'Что интересно людям',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        SizedBox(height: 0.4.h),
                        Text(
                          'Видео отсортированы по доле лайков от просмотров — '
                          'выше значит аудитории интереснее.',
                          style: TextStyle(fontSize: 11.sp, color: _grey),
                        ),
                        SizedBox(height: 1.5.h),
                        ...List.generate(ranked.length, (i) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 2.2.w),
                            child: _RankedVideoRow(
                              rank: i + 1,
                              car: ranked[i],
                              engagement: _engagement(ranked[i]),
                              maxEngagement: maxEngagement,
                            ),
                          );
                        }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 0.5.h, 4.w, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(right: 3.w),
              child: Icon(Icons.arrow_back, color: _ink, size: 3.2.h),
            ),
          ),
          Expanded(
            child: Text(
              'Аналитика канала',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined, size: 6.h, color: const Color(0xFFC8C8CC)),
            SizedBox(height: 1.5.h),
            Text(
              'Пока нет данных',
              style: TextStyle(
                  fontSize: 14.sp, fontWeight: FontWeight.w800, color: _ink),
            ),
            SizedBox(height: 0.7.h),
            Text(
              'Как только появятся публикации с просмотрами и лайками, '
              'здесь будет видно, какие из них интереснее аудитории.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.sp, color: _grey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow({
    required int publications,
    required int totalViews,
    required int totalLikes,
    required double avgEngagement,
  }) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_offer_outlined,
            value: '$publications',
            label: 'Публикаций',
          ),
        ),
        SizedBox(width: 2.5.w),
        Expanded(
          child: _StatCard(
            icon: Icons.remove_red_eye_outlined,
            value: _fmtCount(totalViews),
            label: 'Просмотров',
          ),
        ),
        SizedBox(width: 2.5.w),
        Expanded(
          child: _StatCard(
            icon: Icons.favorite_rounded,
            value: _fmtCount(totalLikes),
            label: 'Лайков',
          ),
        ),
        SizedBox(width: 2.5.w),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up_rounded,
            value: '${(avgEngagement * 100).toStringAsFixed(1)}%',
            label: 'Интерес',
            highlighted: true,
          ),
        ),
      ],
    );
  }

  static String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ── Маленькая карточка сводной цифры ────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool highlighted;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.highlighted = false,
  });

  static const _ink = Color(0xFF0F0F0F);
  static const _grey = Color(0xFF6B6B70);
  static const _accent = Color(0xFF3A6FF8);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 1.6.h, horizontal: 1.5.w),
      decoration: BoxDecoration(
        color: highlighted ? _accent.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(3.5.w),
        border: Border.all(
          color: highlighted ? _accent.withOpacity(0.25) : const Color(0xFFEFEFEF),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 2.2.h, color: highlighted ? _accent : _ink),
          SizedBox(height: 0.7.h),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w800,
                color: highlighted ? _accent : _ink,
              ),
            ),
          ),
          SizedBox(height: 0.2.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8.8.sp, color: _grey),
          ),
        ],
      ),
    );
  }
}

// ── Строка одного видео в рейтинге интереса ─────────────────────────
class _RankedVideoRow extends StatelessWidget {
  final int rank;
  final Car car;
  final double engagement;
  final double maxEngagement;

  const _RankedVideoRow({
    required this.rank,
    required this.car,
    required this.engagement,
    required this.maxEngagement,
  });

  static const _ink = Color(0xFF0F0F0F);
  static const _grey = Color(0xFF6B6B70);
  static const _accent = Color(0xFF3A6FF8);
  static const _gold = Color(0xFFFFB100);

  @override
  Widget build(BuildContext context) {
    // Полоска интереса нормализована относительно лидера списка —
    // у самого залайканного видео она всегда на 100%.
    final barFraction =
        maxEngagement > 0 ? (engagement / maxEngagement).clamp(0.0, 1.0) : 0.0;
    final isTop3 = rank <= 3;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoAnalyticsPage(car: car)),
      ),
      child: Container(
        padding: EdgeInsets.all(2.5.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFEFEFEF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ранг — золотой кружок для топ-3, серый для остальных.
            Container(
              width: 7.w,
              height: 7.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isTop3 ? _gold.withOpacity(0.15) : const Color(0xFFF2F2F5),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: isTop3 ? _gold : _grey,
                ),
              ),
            ),
            SizedBox(width: 3.w),
            ClipRRect(
              borderRadius: BorderRadius.circular(2.5.w),
              child: SizedBox(
                width: 13.w,
                height: 13.w,
                child: car.photoPaths.isNotEmpty
                    ? Image.network(car.photoPaths.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.black12))
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
                        fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: _ink),
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye_outlined, size: 13, color: _grey),
                      SizedBox(width: 1.w),
                      Text('${car.viewsCount}',
                          style: TextStyle(fontSize: 10.sp, color: _grey)),
                      SizedBox(width: 2.5.w),
                      const Icon(Icons.favorite, size: 13, color: Colors.redAccent),
                      SizedBox(width: 1.w),
                      Text('${car.likesCount}',
                          style: TextStyle(fontSize: 10.sp, color: _grey)),
                    ],
                  ),
                  SizedBox(height: 0.8.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFF0F0F3),
                      valueColor: AlwaysStoppedAnimation(
                        isTop3 ? _gold : _accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 2.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(engagement * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: isTop3 ? _gold : _ink,
                  ),
                ),
                SizedBox(height: 0.2.h),
                Text('интерес',
                    style: TextStyle(fontSize: 8.5.sp, color: _grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}