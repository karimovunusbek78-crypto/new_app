import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';

/// Аналитика ОДНОГО видео/объявления.
///
/// Показывает:
///  • карточку авто + дату публикации;
///  • живые счётчики: лайки, сохранения, просмотры, за сегодня, комментарии;
///  • вкладку «Лайкнули» — кто поставил лайк (аватар, имя, когда);
///  • вкладку «Смотрели» — кто посмотрел видео (аватар, имя, когда);
///  • вкладку «Сохранили» — кто добавил авто в «Избранное» (закладка).
///
/// Схема данных (по правилам Firestore проекта):
///  • лайки:      cars/{carId}/likedBy/{uid}   — id документа = uid лайкнувшего
///  • просмотры:  cars/{carId}/viewLog/{logId} — авто-id, uid лежит в поле 'uid'
///  • сохранения: cars/{carId}/savedBy/{uid}   — id документа = uid сохранившего
/// У одного пользователя может быть много записей в viewLog (по записи
/// на просмотр) — в списке «Смотрели» он показывается ОДИН раз,
/// с самым свежим временем просмотра.
class VideoAnalyticsPage extends StatefulWidget {
  final Car car;
  const VideoAnalyticsPage({super.key, required this.car});

  @override
  State<VideoAnalyticsPage> createState() => _VideoAnalyticsPageState();
}

class _VideoAnalyticsPageState extends State<VideoAnalyticsPage> {
  static const _accent = Color(0xFF111111);
  static const _grey = Color(0xFF9A9AA0);

  // Кэш профилей, чтобы не грузить users/{uid} по несколько раз.
  final Map<String, _MiniUser> _userCache = {};

  DocumentReference<Map<String, dynamic>> get _carRef =>
      FirebaseFirestore.instance.collection('cars').doc(widget.car.id);

  Future<_MiniUser> _loadUser(String uid) async {
    final cached = _userCache[uid];
    if (cached != null) return cached;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      final u = _MiniUser(
        name: ((data?['name'] as String?) ?? '').trim(),
        avatarUrl: ((data?['avatarUrl'] as String?) ?? '').trim(),
      );
      _userCache[uid] = u;
      return u;
    } catch (_) {
      return const _MiniUser(name: '', avatarUrl: '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: SafeArea(
          child: Column(
            children: [
              // ── Шапка ────────────────────────────────────────────────
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
                        'Аналитика видео',
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

              // ── Живой док объявления: счётчики + дата публикации ─────
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _carRef.snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final likes =
                      (data?['likesCount'] as int?) ?? widget.car.likesCount;
                  final views =
                      (data?['viewsCount'] as int?) ?? widget.car.viewsCount;
                  final saves = (data?['savesCount'] as int?) ?? 0;
                  final published = _extractTs(data);

                  return Padding(
                    padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 0),
                    child: Column(
                      children: [
                        _carCard(published),
                        SizedBox(height: 1.5.h),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.favorite_rounded,
                                value: '$likes',
                                label: 'Лайки',
                              ),
                            ),
                            SizedBox(width: 2.5.w),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.bookmark_rounded,
                                value: '$saves',
                                label: 'Сохранения',
                              ),
                            ),
                            SizedBox(width: 2.5.w),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.remove_red_eye_outlined,
                                value: '$views',
                                label: 'Просмотры',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1.5.h),
                        Row(
                          children: [
                            Expanded(child: _todayCard()),
                            SizedBox(width: 2.5.w),
                            Expanded(child: _commentsCard()),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              SizedBox(height: 1.5.h),

              // ── Вкладки: кто лайкнул / кто смотрел / кто сохранил ────
              TabBar(
                labelColor: _accent,
                unselectedLabelColor: _grey,
                indicatorColor: _accent,
                indicatorWeight: 2.5,
                labelStyle:
                    TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800),
                tabs: const [
                  Tab(text: 'Лайкнули'),
                  Tab(text: 'Смотрели'),
                  Tab(text: 'Сохранили'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Лайки: id документа = uid лайкнувшего.
                    _peopleList(
                      collection: 'likedBy',
                      dedupe: false,
                      emptyIcon: Icons.favorite_border_rounded,
                      emptyText: 'Пока никто не лайкнул',
                    ),
                    // Просмотры: uid в поле 'uid', записей может быть
                    // несколько на человека — дедупим.
                    _peopleList(
                      collection: 'viewLog',
                      dedupe: true,
                      emptyIcon: Icons.visibility_off_outlined,
                      emptyText: 'Пока нет просмотров',
                    ),
                    // Сохранения: id документа = uid сохранившего
                    // (cars/{carId}/savedBy/{uid}).
                    _peopleList(
                      collection: 'savedBy',
                      dedupe: false,
                      emptyIcon: Icons.bookmark_border_rounded,
                      emptyText: 'Пока никто не сохранил',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Карточка авто + дата публикации ─────────────────────────────────
  Widget _carCard(DateTime? published) {
    final car = widget.car;
    return Container(
      padding: EdgeInsets.all(3.w),
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
                  style:
                      TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 0.5.h),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 1.8.h, color: _grey),
                    SizedBox(width: 1.w),
                    Flexible(
                      child: Text(
                        published != null
                            ? 'Опубликовано ${_fmtDate(published)}'
                            : 'Дата публикации неизвестна',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5.sp, color: _grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Карточка «за сегодня» (через провайдер) ──────────────────────────
  Widget _todayCard() {
    return FutureBuilder<int>(
      future: context.read<CarsProvider>().viewsToday(widget.car.id),
      builder: (context, snap) => _StatCard(
        icon: Icons.today_outlined,
        value: '${snap.data ?? 0}',
        label: 'Сегодня',
      ),
    );
  }

  // ── Карточка комментариев (агрегатный count, дёшево) ─────────────────
  Widget _commentsCard() {
    return FutureBuilder<AggregateQuerySnapshot>(
      future: _carRef.collection('comments').count().get(),
      builder: (context, snap) => _StatCard(
        icon: Icons.mode_comment_outlined,
        value: '${snap.data?.count ?? 0}',
        label: 'Комменты',
      ),
    );
  }

  // ── Список людей из подколлекции (likedBy / viewLog / savedBy) ───────
  Widget _peopleList({
    required String collection,
    required bool dedupe,
    required IconData emptyIcon,
    required String emptyText,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _carRef.collection(collection).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return _empty(Icons.lock_outline_rounded,
              'Нет доступа к данным\n(проверь правила Firestore)');
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _empty(emptyIcon, emptyText);

        var entries = docs.map((d) {
          final data = d.data();
          final fieldUid = ((data['uid'] as String?) ?? '').trim();
          // likedBy/savedBy: uid = id документа; viewLog: uid = поле 'uid'.
          final uid = fieldUid.isNotEmpty ? fieldUid : d.id;
          return _PersonEntry(uid: uid, time: _extractTs(data));
        }).toList();

        // viewLog: один человек — много записей. Оставляем по одной
        // на человека, с самым свежим временем.
        if (dedupe) {
          final byUid = <String, _PersonEntry>{};
          for (final e in entries) {
            final prev = byUid[e.uid];
            if (prev == null ||
                (e.time != null &&
                    (prev.time == null || e.time!.isAfter(prev.time!)))) {
              byUid[e.uid] = e;
            }
          }
          entries = byUid.values.toList();
        }

        // Свежие сверху (если есть таймстемп).
        entries.sort((a, b) {
          final at = a.time, bt = b.time;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(5.w, 1.5.h, 5.w, 3.h),
          itemCount: entries.length,
          itemBuilder: (context, i) => _PersonTile(
            entry: entries[i],
            loadUser: _loadUser,
          ),
        );
      },
    );
  }

  Widget _empty(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 4.h, color: _grey),
          SizedBox(height: 1.h),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: _grey, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Достаём Timestamp из разных возможных полей ──────────────────────
  static DateTime? _extractTs(Map<String, dynamic>? data) {
    if (data == null) return null;
    for (final key in [
      'createdAt',
      'timestamp',
      'date',
      'publishedAt',
      'savedAt'
    ]) {
      final v = data[key];
      if (v is Timestamp) return v.toDate();
    }
    return null;
  }

  static const _months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  static String _fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';
}

class _PersonEntry {
  final String uid;
  final DateTime? time;
  const _PersonEntry({required this.uid, required this.time});
}

class _MiniUser {
  final String name;
  final String avatarUrl;
  const _MiniUser({required this.name, required this.avatarUrl});
}

// ── Плитка человека: аватар, имя, «когда» ─────────────────────────────
class _PersonTile extends StatelessWidget {
  final _PersonEntry entry;
  final Future<_MiniUser> Function(String uid) loadUser;

  const _PersonTile({required this.entry, required this.loadUser});

  String _timeAgo(DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return '${t.day.toString().padLeft(2, '0')}.'
        '${t.month.toString().padLeft(2, '0')}.${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MiniUser>(
      future: loadUser(entry.uid),
      builder: (context, snap) {
        final user = snap.data;
        final name = (user != null && user.name.isNotEmpty)
            ? user.name
            : 'Пользователь';
        final avatarUrl = user?.avatarUrl ?? '';
        final initials = name.isNotEmpty ? name[0].toUpperCase() : 'П';

        return Container(
          margin: EdgeInsets.only(bottom: 2.w),
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3.5.w),
            border: Border.all(color: const Color(0xFFEFEFEF)),
          ),
          child: Row(
            children: [
              Container(
                width: 10.w,
                height: 10.w,
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
                            fontSize: 12.sp,
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
                  style:
                      TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _timeAgo(entry.time),
                style:
                    TextStyle(fontSize: 10.sp, color: const Color(0xFF9A9AA0)),
              ),
            ],
          ),
        );
      },
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
      padding: EdgeInsets.symmetric(vertical: 1.6.h, horizontal: 1.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF111111), size: 2.4.h),
          SizedBox(height: 0.8.h),
          Text(
            value,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 0.2.h),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9.sp, color: const Color(0xFF9A9AA0)),
          ),
        ],
      ),
    );
  }
}