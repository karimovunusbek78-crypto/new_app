import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/home/providers/subscribtion_provider.dart';

/// Публичный профиль автора объявления. Открывается по тапу на
/// аватар/имя в ленте видео — раньше тап туда никуда не вёл.
class PublicProfilePage extends StatelessWidget {
  final String uid;
  const PublicProfilePage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = myUid == uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Профиль', style: TextStyle(color: Colors.black)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          final data = userSnap.data?.data();
          final name = (data?['name'] as String?)?.trim().isNotEmpty == true
              ? data!['name'] as String
              : 'Пользователь';
          final avatarUrl = data?['avatarUrl'] as String?;
          final subsCount = (data?['subscribersCount'] as num?)?.toInt() ?? 0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 9.w,
                      backgroundColor: Colors.black12,
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700))
                          : null,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800)),
                          SizedBox(height: 0.5.h),
                          Text('$subsCount подписчиков',
                              style: TextStyle(fontSize: 12.5.sp, color: Colors.black54)),
                        ],
                      ),
                    ),
                    if (!isMe)
                      Consumer<SubscriptionsProvider>(
                        builder: (context, subs, _) {
                          final subscribed = subs.isSubscribed(uid);
                          final pending = subs.isPending(uid);
                          return GestureDetector(
                            onTap: pending ? null : () => subs.toggleSubscribe(uid),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                              decoration: BoxDecoration(
                                color: subscribed ? Colors.white : Colors.black,
                                borderRadius: BorderRadius.circular(8.w),
                                border: Border.all(color: Colors.black, width: 1.2),
                              ),
                              child: Text(
                                subscribed ? 'Вы подписаны' : 'Подписаться',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: subscribed ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                SizedBox(height: 3.h),
                Text('Объявления', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800)),
                SizedBox(height: 1.5.h),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('cars')
                      .where('ownerId', isEqualTo: uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: Text('Пока нет объявлений',
                            style: TextStyle(fontSize: 13.sp, color: Colors.black45)),
                      );
                    }
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 3.w,
                        mainAxisSpacing: 3.w,
                        childAspectRatio: 0.85,
                      ),
                      itemBuilder: (context, i) {
                        final car = Car.fromFirestore(docs[i].id, docs[i].data());
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CarDetailPage(car: car)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3.w),
                            child: Container(
                              color: const Color(0xFFF2F2F7),
                              child: car.photoPaths.isNotEmpty
                                  ? Image.network(
                                      car.photoPaths.first,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.directions_car_outlined),
                                    )
                                  : const Icon(Icons.directions_car_outlined),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}