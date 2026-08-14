import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';

/// Public "profile" page for an autosalon — the salon equivalent of
/// UserStatsPage. Everything here is read live from Firestore
/// (autosalons/{salonId} + autosalons/{salonId}/locations + cars where
/// autosalonId == salonId), so once an autosalon is published it stays
/// visible and up to date instead of only living in local widget state.
///
/// Reached from:
///  - the "Все авто →" banner on an autosalon car inside VideoPage
///  - AutoslonPublishPage after a successful publish (own salon)
class AutosalonStatsPage extends StatefulWidget {
  final String salonId;
  const AutosalonStatsPage({Key? key, required this.salonId}) : super(key: key);

  @override
  State<AutosalonStatsPage> createState() => _AutosalonStatsPageState();
}

class _AutosalonStatsPageState extends State<AutosalonStatsPage> {
  static const _accent = Color(0xFF111111);
  static const _gold = Color(0xFFC0392B);
  static const _bg = Color(0xFFF5F5F7);
  static const _hair = Color(0xFFEFEFEF);
  static const _muted = Color(0xFF9A9AA0);

  DocumentReference<Map<String, dynamic>> get _salonRef =>
      FirebaseFirestore.instance.collection('autosalons').doc(widget.salonId);

  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == widget.salonId;

  VideoPlayerController? _galleryVideoController;
  bool _galleryVideoReady = false;
  String? _galleryVideoUrlLoaded;

  @override
  void dispose() {
    _galleryVideoController?.dispose();
    super.dispose();
  }

  void _ensureGalleryVideo(String? url) {
    if (url == null || url.isEmpty) return;
    if (_galleryVideoUrlLoaded == url) return;
    _galleryVideoUrlLoaded = url;
    _galleryVideoController?.dispose();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    controller.initialize().then((_) {
      if (!mounted) return;
      controller.setLooping(true);
      setState(() {
        _galleryVideoController = controller;
        _galleryVideoReady = true;
      });
    }).catchError((_) {});
  }

  Future<void> _callPhone(String phone) async {
    if (phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:${phone.trim()}');
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _openWhatsApp(String phone) async {
    if (phone.trim().isEmpty) return;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openInMaps(String city, String address) async {
    final query = Uri.encodeComponent('$city, $address'.trim());
    if (query.isEmpty) return;
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _salonRef.snapshots(),
          builder: (context, salonSnap) {
            if (salonSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = salonSnap.data?.data();
            if (data == null) {
              return _notFoundView();
            }

            final name = (data['name'] as String?)?.trim() ?? '';
            final tagline = (data['tagline'] as String?)?.trim() ?? '';
            final years = (data['yearsOnMarket'] as String?)?.trim() ?? '';
            final logoUrl = data['logoUrl'] as String?;
            final phone = (data['phone'] as String?)?.trim() ?? '';
            final description = (data['description'] as String?)?.trim() ?? '';
            final photoUrls =
                (data['photoUrls'] as List?)?.whereType<String>().toList() ??
                    const <String>[];
            final videoUrl = data['videoUrl'] as String?;
            _ensureGalleryVideo(videoUrl);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _backBar()),
                SliverToBoxAdapter(
                  child: _header(
                    name: name,
                    tagline: tagline,
                    years: years,
                    logoUrl: logoUrl,
                    phone: phone,
                  ),
                ),
                if (description.isNotEmpty)
                  SliverToBoxAdapter(child: _descriptionCard(description)),
                SliverToBoxAdapter(child: _sectionHeader('Локации')),
                SliverToBoxAdapter(child: _locationsSection()),
                if (photoUrls.isNotEmpty || videoUrl != null) ...[
                  SliverToBoxAdapter(child: _sectionHeader('Фото и видео салона')),
                  SliverToBoxAdapter(
                    child: _gallerySection(photoUrls, videoUrl),
                  ),
                ],
                SliverToBoxAdapter(child: _carsHeader()),
                _carsGridSliver(),
                SliverToBoxAdapter(child: SizedBox(height: 4.h)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _notFoundView() {
    return Column(
      children: [
        _backBar(),
        Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18.w,
                    height: 18.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Icon(Icons.storefront_outlined,
                        color: const Color(0xFFCACACE), size: 7.h),
                  ),
                  SizedBox(height: 2.5.h),
                  Text(
                    'Автосалон не найден',
                    style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.black),
                  ),
                  SizedBox(height: 0.8.h),
                  Text(
                    'Возможно, он ещё не опубликован или был удалён.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.sp, color: _muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _backBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(3.w, 0.5.h, 3.w, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.all(1.6.w),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Icon(Icons.arrow_back, color: Colors.black, size: 2.6.h),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 3.w),
              child: Text(
                'Автосалон',
                style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header: logo, name, tagline, years, contact buttons ──────────
  Widget _header({
    required String name,
    required String tagline,
    required String years,
    required String? logoUrl,
    required String phone,
  }) {
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(4.5.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5.5.w),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 17.w,
                  height: 17.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F1EC),
                    borderRadius: BorderRadius.circular(4.w),
                    border:
                        Border.all(color: const Color(0xFFE7DFD6), width: 1.2),
                  ),
                  child: hasLogo
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4.w),
                          child: Image.network(logoUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                  Icons.storefront_outlined,
                                  color: _gold,
                                  size: 4.5.h)),
                        )
                      : Icon(Icons.storefront_outlined,
                          color: _gold, size: 4.5.h),
                ),
                SizedBox(width: 3.5.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name.isEmpty ? 'Автосалон' : name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                  height: 1.15),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 0.2.h, left: 1.w),
                            child: Icon(Icons.verified_rounded,
                                size: 2.2.h, color: const Color(0xFF34C759)),
                          ),
                        ],
                      ),
                      if (tagline.isNotEmpty) ...[
                        SizedBox(height: 0.5.h),
                        Text(
                          tagline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12.sp, color: _muted, height: 1.35),
                        ),
                      ],
                      if (years.isNotEmpty) ...[
                        SizedBox(height: 0.8.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 2.6.w, vertical: 0.4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F4),
                            borderRadius: BorderRadius.circular(2.w),
                          ),
                          child: Text('$years лет на рынке',
                              style: TextStyle(
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF636366))),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (phone.isNotEmpty) ...[
              SizedBox(height: 2.2.h),
              Row(
                children: [
                  Expanded(
                    child: _contactButton(
                      icon: Icons.phone_rounded,
                      label: 'Позвонить',
                      onTap: () => _callPhone(phone),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: _contactButton(
                      icon: Icons.chat_bubble_rounded,
                      label: 'WhatsApp',
                      filled: true,
                      color: const Color(0xFF25D366),
                      onTap: () => _openWhatsApp(phone),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contactButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = _accent,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.5.h),
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          borderRadius: BorderRadius.circular(3.5.w),
          border: filled ? null : Border.all(color: _hair),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 2.h, color: filled ? Colors.white : color),
            SizedBox(width: 1.5.w),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: filled ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _descriptionCard(String description) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 2.5.h, 4.w, 0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.5.w),
          border: Border.all(color: _hair),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('О салоне',
                style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: _muted,
                    letterSpacing: 0.3)),
            SizedBox(height: 0.8.h),
            Text(
              description,
              style: TextStyle(
                  fontSize: 12.5.sp, color: const Color(0xFF3C3C43), height: 1.55),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(5.w, 3.2.h, 5.w, 1.2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: -0.2),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ── Locations ──────────────────────────────────────────────────
  // Read-only list, same for everyone (owner included). Tapping a card
  // opens a detail sheet with the full photo set, address and quick
  // actions (open in Maps / call salon) — it doesn't let anyone create
  // or edit locations here.
  Widget _locationsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _salonRef.collection('locations').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 16.h,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (docs.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Text(
              'Локации пока не добавлены',
              style: TextStyle(fontSize: 12.sp, color: _muted),
            ),
          );
        }
        return SizedBox(
          height: 16.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            itemCount: docs.length,
            separatorBuilder: (_, __) => SizedBox(width: 3.w),
            itemBuilder: (_, i) {
              final d = docs[i].data();
              final city = (d['city'] as String?) ?? '';
              final address = (d['address'] as String?) ?? '';
              final lat = (d['lat'] as num?)?.toDouble();
              final lng = (d['lng'] as num?)?.toDouble();
              final photoUrls =
                  (d['photoUrls'] as List?)?.whereType<String>().toList() ??
                      const <String>[];
              return _locationCard(city, address, photoUrls, lat, lng);
            },
          ),
        );
      },
    );
  }

  Widget _locationCard(String city, String address, List<String> photoUrls,
      double? lat, double? lng) {
    final hasPhotos = photoUrls.isNotEmpty;
    return GestureDetector(
      onTap: () => _showLocationDetails(city, address, photoUrls, lat, lng),
      child: Container(
        width: 46.w,
        height: 16.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4.5.w),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.09),
                blurRadius: 14,
                offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.5.w),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPhotos)
                photoUrls.length == 1
                    ? Image.network(
                        photoUrls[0],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1A1A1C),
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.white.withOpacity(0.3), size: 4.h),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Image.network(
                              photoUrls[0],
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: const Color(0xFF1A1A1C)),
                            ),
                          ),
                          Container(width: 1, color: Colors.black26),
                          Expanded(
                            child: Image.network(
                              photoUrls[1],
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: const Color(0xFF1A1A1C)),
                            ),
                          ),
                        ],
                      )
              else
                Container(color: const Color(0xFF1A1A1C)),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(hasPhotos ? 0.12 : 0.0),
                      Colors.black.withOpacity(0.62),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                right: 2.6.w,
                top: 1.4.h,
                child: Container(
                  padding: EdgeInsets.all(1.3.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.open_in_full_rounded,
                      color: Colors.white, size: 1.6.h),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(3.w, 0, 3.w, 1.5.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(city,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800)),
                      Text(address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Small read-only map card — same visual language (OSM tiles + pin) as
  // the map in LocationAddPage, just non-editable here.
  Widget _locationMapCard(double lat, double lng) {
    final point = LatLng(lat, lng);
    return Container(
      height: 20.h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: _hair),
      ),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: point,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.newapp.autosalon',
          ),
          MarkerLayer(markers: [
            Marker(
              point: point,
              width: 10.w,
              height: 10.w,
              alignment: Alignment.topCenter,
              child: Icon(Icons.location_on, color: _accent, size: 9.w),
            ),
          ]),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }

  // Full-screen-ish detail sheet shown to anyone (owner or visitor) who
  // taps a location card: bigger photo carousel, an embedded map pin
  // (same style as LocationAddPage), full address, and quick actions.
  void _showLocationDetails(String city, String address,
      List<String> photoUrls, double? lat, double? lng) {
    final hasCoords = lat != null && lng != null && (lat != 0 || lng != 0);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  Center(
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 1.4.h),
                      width: 10.w,
                      height: 0.5.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (photoUrls.isNotEmpty)
                    SizedBox(
                      height: 26.h,
                      child: PageView(
                        children: [
                          for (final url in photoUrls)
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFF2F2F4),
                                child: Icon(Icons.broken_image_outlined,
                                    color: const Color(0xFFB4B4BA), size: 5.h),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    Container(
                      height: 20.h,
                      margin: EdgeInsets.symmetric(horizontal: 5.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F4),
                        borderRadius: BorderRadius.circular(4.w),
                      ),
                      child: Icon(Icons.location_on_outlined,
                          color: const Color(0xFFB4B4BA), size: 5.h),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(5.w, 2.4.h, 5.w, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(city.isEmpty ? 'Локация' : city,
                            style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.black)),
                        SizedBox(height: 0.6.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 2.h, color: _gold),
                            SizedBox(width: 1.5.w),
                            Expanded(
                              child: Text(
                                address.isEmpty ? 'Адрес не указан' : address,
                                style: TextStyle(
                                    fontSize: 12.5.sp,
                                    color: const Color(0xFF3C3C43),
                                    height: 1.45),
                              ),
                            ),
                          ],
                        ),
                        if (hasCoords) ...[
                          SizedBox(height: 2.h),
                          _locationMapCard(lat, lng),
                        ],
                        SizedBox(height: 2.6.h),
                        Row(
                          children: [
                            Expanded(
                              child: _contactButton(
                                icon: Icons.map_rounded,
                                label: 'Маршрут',
                                filled: true,
                                color: _accent,
                                onTap: () => _openInMaps(city, address),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3.h),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Salon gallery: general photos + optional promo video ─────────
  Widget _gallerySection(List<String> photoUrls, String? videoUrl) {
    final tile = 26.w;
    return SizedBox(
      height: tile,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 5.w),
        children: [
          if (videoUrl != null)
            Padding(
              padding: EdgeInsets.only(right: 3.w),
              child: _galleryVideoTile(tile, videoUrl),
            ),
          for (final url in photoUrls)
            Padding(
              padding: EdgeInsets.only(right: 3.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3.5.w),
                child: Image.network(
                  url,
                  width: tile,
                  height: tile,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: tile,
                    height: tile,
                    color: const Color(0xFFF2F2F4),
                    child: Icon(Icons.broken_image_outlined,
                        color: const Color(0xFFB4B4BA), size: 3.h),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _galleryVideoTile(double tile, String url) {
    final ready = _galleryVideoReady && _galleryVideoUrlLoaded == url;
    return GestureDetector(
      onTap: () {
        final c = _galleryVideoController;
        if (c == null) return;
        setState(() => c.value.isPlaying ? c.pause() : c.play());
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3.5.w),
        child: SizedBox(
          width: tile,
          height: tile,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (ready)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _galleryVideoController!.value.size.width,
                    height: _galleryVideoController!.value.size.height,
                    child: VideoPlayer(_galleryVideoController!),
                  ),
                )
              else
                Container(
                  color: const Color(0xFF111111),
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                ),
              if (ready)
                IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _galleryVideoController!.value.isPlaying
                          ? 0.0
                          : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 9.w,
                        height: 9.w,
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cars ──────────────────────────────────────────────────────
  Widget _carsHeader() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('cars')
          .where('autosalonId', isEqualTo: widget.salonId)
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Padding(
          padding: EdgeInsets.fromLTRB(5.w, 3.2.h, 5.w, 1.2.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Автомобили',
                style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: -0.2),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.2.w, vertical: 0.3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F4),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 11.sp,
                        color: const Color(0xFF636366),
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _carsGridSliver() {
    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('cars')
            .where('autosalonId', isEqualTo: widget.salonId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
              child: Text(
                'Автомобили пока не добавлены',
                style: TextStyle(fontSize: 12.sp, color: _muted),
              ),
            );
          }
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 3.w,
              crossAxisSpacing: 3.w,
              childAspectRatio: 0.72,
            ),
            itemCount: docs.length,
            itemBuilder: (_, i) => _carGridTile(docs[i].id, docs[i].data()),
          );
        },
      ),
    );
  }

  Widget _carGridTile(String id, Map<String, dynamic> d) {
    final photoPaths =
        (d['photoPaths'] as List?)?.whereType<String>().toList() ?? const [];
    final name = (d['name'] as String?) ?? '';
    final price = (d['price'] as String?) ?? '';
    final year = (d['year'] as String?) ?? '';
    final viewsCount = (d['viewsCount'] as num?)?.toInt() ?? 0;
    final likesCount = (d['likesCount'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: () {
        final car = Car.fromMap(id, d);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CarDetailPage(car: car)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(4.w)),
              child: AspectRatio(
                aspectRatio: 1.15,
                child: photoPaths.isNotEmpty
                    ? Image.network(
                        photoPaths.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF2F2F4),
                          child: Icon(Icons.directions_car_outlined,
                              color: const Color(0xFFB4B4BA), size: 4.h),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFF2F2F4),
                        child: Icon(Icons.directions_car_outlined,
                            color: const Color(0xFFB4B4BA), size: 4.h),
                      ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(2.4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Без названия' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black)),
                  SizedBox(height: 0.2.h),
                  Text(
                    [
                      if (year.trim().isNotEmpty) year.trim(),
                      price.isEmpty ? '—' : price,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5.sp,
                        color: _muted,
                        fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      Icon(Icons.visibility_outlined,
                          size: 1.5.h, color: const Color(0xFFB4B4BA)),
                      SizedBox(width: 0.6.w),
                      Text('$viewsCount',
                          style: TextStyle(
                              fontSize: 9.5.sp, color: const Color(0xFFB4B4BA))),
                      SizedBox(width: 2.w),
                      Icon(Icons.favorite_rounded,
                          size: 1.5.h, color: const Color(0xFFB4B4BA)),
                      SizedBox(width: 0.6.w),
                      Text('$likesCount',
                          style: TextStyle(
                              fontSize: 9.5.sp, color: const Color(0xFFB4B4BA))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}