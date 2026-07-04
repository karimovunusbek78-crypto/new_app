import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:new_app/src/pages/home/providers/subscribtion_provider.dart';

class MyStatsPage extends StatelessWidget {
  const MyStatsPage({super.key});

  static const _accent = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final myCars = context.watch<CarsProvider>().myCars(uid);
    final totalLikes = myCars.fold<int>(0, (sum, c) => sum + c.likesCount);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(5.w, 0.5.h, 5.w, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.only(right: 3.w),
                      child: Icon(Icons.arrow_back, color: _accent, size: 3.2.h),
                    ),
                  ),
                  Text(
                    'Моя статистика',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: _accent,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 3.h),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SubscribersCard(uid: uid, accent: _accent),
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
                          value: '${myCars.length}',
                          label: 'Опубликовано',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'Мои объявления',
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.w800, color: _accent),
                  ),
                  SizedBox(height: 1.5.h),
                  if (myCars.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Center(
                        child: Text(
                          'У вас пока нет объявлений',
                          style: TextStyle(
                              fontSize: 13.sp, color: const Color(0xFF9A9AA0)),
                        ),
                      ),
                    )
                  else
                    ...myCars.map((c) => _CarStatRow(car: c)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Карточка подписчиков (живой стрим из users/{uid}) ─────────────────
class _SubscribersCard extends StatelessWidget {
  final String uid;
  final Color accent;
  const _SubscribersCard({required this.uid, required this.accent});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final count = (snap.data?.data() as Map<String, dynamic>?)?['subscribersCount'] ?? 0;
        return _StatCard(
          icon: Icons.people_alt_outlined,
          value: '$count',
          label: 'Подписчики',
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCard({required this.icon, required this.value, required this.label});

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

// ── Строка объявления со статами + удалением ──────────────────────────
class _CarStatRow extends StatelessWidget {
  final Car car;
  const _CarStatRow({required this.car});

  static const _reasons = [
    'Уже продано',
    'Передумал продавать',
    'Указал неверные данные',
    'Другая причина',
  ];

  Future<void> _confirmDelete(BuildContext context) async {
    String selectedReason = _reasons.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Удалить объявление?',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Объявление пропадёт из приложения, и никто больше не сможет его увидеть.',
                style: TextStyle(fontSize: 12.5.sp, color: const Color(0xFF8A8A8E)),
              ),
              SizedBox(height: 1.h),
              ..._reasons.map(
                (r) => RadioListTile<String>(
                  value: r,
                  groupValue: selectedReason,
                  activeColor: Colors.black,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r, style: TextStyle(fontSize: 13.sp)),
                  onChanged: (v) => setDialogState(() => selectedReason = v!),
                ),
              ),
            ],
          ),
          actions: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Отмена', style: TextStyle(color: Colors.black)),
                ),
              ),
              SizedBox(width: 2.5.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Удалить'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<CarsProvider>().deleteCar(car.id, reason: selectedReason);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  ? Image.network(car.photoPaths.first, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black12))
                  : Container(
                      color: Colors.black12,
                      child: const Icon(Icons.directions_car_outlined, color: Colors.black38),
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
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 0.7.h),
                Row(
                  children: [
                    const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
                    SizedBox(width: 1.w),
                    Text('${car.likesCount}', style: TextStyle(fontSize: 10.5.sp)),
                    SizedBox(width: 3.w),
                    const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.grey),
                    SizedBox(width: 1.w),
                    Text('${car.viewsCount}', style: TextStyle(fontSize: 10.5.sp)),
                    SizedBox(width: 3.w),
                    FutureBuilder<int>(
                      future: context.read<CarsProvider>().viewsToday(car.id),
                      builder: (context, snap) {
                        final today = snap.data ?? 0;
                        return Row(
                          children: [
                            const Icon(Icons.today_outlined, size: 14, color: Colors.blueGrey),
                            SizedBox(width: 1.w),
                            Text('$today сегодня', style: TextStyle(fontSize: 10.5.sp)),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _confirmDelete(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(1.5.w),
              child: const Icon(Icons.delete_outline, color: Color(0xFF8A8A90)),
            ),
          ),
        ],
      ),
    );
  }
}