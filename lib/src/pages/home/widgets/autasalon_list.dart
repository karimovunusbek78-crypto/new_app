import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:new_app/src/video/video%20page/profile/autosalon_stats_page.dart';
import 'package:responsive_sizer/responsive_sizer.dart';


class AutosalonList extends StatelessWidget {
  const AutosalonList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('autosalons')
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        // Ничего не публиковали ещё — секцию просто не показываем.
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: Text(
                'Автосалоны',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ),
            SizedBox(height: 1.5.h),
            SizedBox(
              height: 16.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 5.w),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  return Padding(
                    padding: EdgeInsets.only(right: 3.w),
                    child: AutosalonCard(
                      salonId: docs[i].id,
                      name: (d['name'] as String?)?.trim().isNotEmpty == true
                          ? d['name']
                          : 'Автосалон',
                      subtitle: _subtitle(d),
                      carsCount: (d['carsCount'] as num?)?.toInt() ?? 0,
                      logoUrl: d['logoUrl'] as String?,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _subtitle(Map<String, dynamic> d) {
    final tagline = (d['tagline'] as String?)?.trim();
    if (tagline != null && tagline.isNotEmpty) return tagline;
    final years = (d['yearsOnMarket'] as String?)?.trim();
    if (years != null && years.isNotEmpty) return '$years лет на рынке';
    return '';
  }
}

class AutosalonCard extends StatelessWidget {
  final String salonId;
  final String name;
  final String subtitle;
  final int carsCount;
  final String? logoUrl;

  const AutosalonCard({
    super.key,
    required this.salonId,
    required this.name,
    required this.subtitle,
    required this.carsCount,
    this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AutosalonStatsPage(salonId: salonId),
        ),
      ),
      child: Container(
        width: 46.w,
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9.w,
                  height: 9.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A6FF8).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2.5.w),
                    image: hasLogo
                        ? DecorationImage(
                            image: NetworkImage(logoUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: hasLogo
                      ? null
                      : const Icon(Icons.store, color: Color(0xFF3A6FF8)),
                ),
                SizedBox(width: 2.5.w),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.2.h),
            if (subtitle.isNotEmpty)
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.sp, color: const Color(0xFF8E8E93)),
                ),
              )
            else
              const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 2.2.w, vertical: 0.4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Text(
                  '$carsCount авто',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF636366),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}