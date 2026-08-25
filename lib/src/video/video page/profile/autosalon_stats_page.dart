import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/pages/car_detail_page.dart';
import 'package:new_app/src/pages/pages.dart'; // ProfileEdit
import 'package:new_app/src/pages/autoslon/location/location_add_page.dart';

/// Public "profile" page for an autosalon — the salon equivalent of
/// UserStatsPage. Everything here is loaded ONCE from Firestore
/// (autosalons/{salonId} + autosalons/{salonId}/locations + cars where
/// autosalonId == salonId) instead of live streams — matches the
/// one-time-fetch pattern used elsewhere in the app. Pull-to-refresh
/// re-runs the same three loads.
///
/// If the current user IS the salon owner, they get an edit pencil on
/// the header (updates name/tagline/years/logo), an "add car" tile
/// in the grid (same fields/flow as AutoslonPublishPage's car form),
/// and full location management (add / edit / delete / photos) — same
/// LocationAddPage flow used during initial publish.
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

  // ── One-time data ────────────────────────────────────────────
  bool _loading = true;
  Map<String, dynamic>? _salonData;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _locationDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _carDocs = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _galleryVideoController?.dispose();
    super.dispose();
  }

  // Каждый запрос изолирован в своём try/catch — если, например,
  // подколлекция locations недоступна, это не должно ронять всю
  // страницу с "Автосалон не найден".
  Future<void> _loadAll() async {
    if (mounted) setState(() => _loading = true);
    await Future.wait([_loadSalon(), _loadLocations(), _loadCars()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSalon() async {
    try {
      final snap = await _salonRef.get();
      _salonData = snap.data();
    } catch (e) {
      debugPrint('Failed to load salon ${widget.salonId}: $e');
      _salonData = null;
    }
  }

  Future<void> _loadLocations() async {
    try {
      final snap = await _salonRef.collection('locations').get();
      _locationDocs = snap.docs;
    } catch (e) {
      debugPrint('Failed to load locations for ${widget.salonId}: $e');
      _locationDocs = [];
    }
  }

  Future<void> _loadCars() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('cars')
          .where('autosalonId', isEqualTo: widget.salonId)
          .orderBy('createdAt', descending: true)
          .get();
      _carDocs = snap.docs;
    } catch (e) {
      debugPrint('Failed to load cars for ${widget.salonId}: $e');
      _carDocs = [];
    }
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

  // ── Owner: edit salon profile ───────────────────────────────────
  Future<void> _editSalonProfile(Map<String, dynamic> currentData) async {
    final result = await Navigator.push<(String, String, String, XFile?)>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEdit(
          initialName: (currentData['name'] as String?) ?? '',
          initialTagline: (currentData['tagline'] as String?) ?? '',
          initialYears: (currentData['yearsOnMarket'] as String?) ?? '',
          initialLogo: null,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final name = result.$1.trim();
    final tagline = result.$2.trim();
    final years = result.$3.trim();
    final newLogo = result.$4;

    _showBlockingLoader('Сохраняем профиль…');
    try {
      String? logoUrl = currentData['logoUrl'] as String?;
      if (newLogo != null) {
        final uid = widget.salonId;
        final ref = FirebaseStorage.instance.ref(
            'autosalons/$uid/logo_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(File(newLogo.path)).timeout(const Duration(seconds: 45));
        logoUrl = await ref.getDownloadURL();
      }
      await _salonRef.set({
        'name': name,
        'tagline': tagline,
        'yearsOnMarket': years,
        if (logoUrl != null) 'logoUrl': logoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _loadSalon();
    } catch (e) {
      debugPrint('Failed to update salon profile ${widget.salonId}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Не удалось сохранить: $e')));
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) setState(() {});
    }
  }

  // ── Owner: manage locations (add / edit / delete) ────────────────
  // Same LocationAddPage flow used during initial publish (AutoslonPublishPage),
  // so adding/editing a location here looks and behaves identically.
  Future<void> _addLocationTapped() async {
    final result =
        await Navigator.push<(String, String, double, double, List<XFile>)>(
      context,
      MaterialPageRoute(builder: (_) => const LocationAddPage()),
    );
    if (result == null || !mounted) return;
    await _saveNewLocation(
      city: result.$1,
      address: result.$2,
      lat: result.$3,
      lng: result.$4,
      photos: result.$5,
    );
  }

  Future<void> _saveNewLocation({
    required String city,
    required String address,
    required double lat,
    required double lng,
    required List<XFile> photos,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.salonId) return;
    final uid = widget.salonId;

    _showBlockingLoader('Добавляем локацию…');
    try {
      final locDoc = _salonRef.collection('locations').doc();
      final photoUrls = <String>[];
      for (var p = 0; p < photos.length; p++) {
        final url = await _uploadFile(
          File(photos[p].path),
          'autosalons/$uid/locations/${locDoc.id}/photo_$p.jpg',
        );
        if (url != null) photoUrls.add(url);
      }
      await locDoc.set({
        'city': city,
        'address': address,
        'lat': lat,
        'lng': lng,
        'photoUrls': photoUrls,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _loadLocations();
    } catch (e) {
      debugPrint('Failed to add location for salon $uid: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось добавить локацию: $e')));
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) setState(() {});
    }
  }

  // Edit form is pre-filled with the current city/address/coordinates.
  // Photos can't be pre-filled as local files (they're already-uploaded
  // network URLs), so: pick new photos → they REPLACE the old ones;
  // leave photos empty → the existing photoUrls are kept untouched.
  Future<void> _editLocationTapped(
      String docId, Map<String, dynamic> data) async {
    final city = (data['city'] as String?) ?? '';
    final address = (data['address'] as String?) ?? '';
    final lat = (data['lat'] as num?)?.toDouble() ?? 0;
    final lng = (data['lng'] as num?)?.toDouble() ?? 0;
    final existingPhotoUrls =
        (data['photoUrls'] as List?)?.whereType<String>().toList() ??
            const <String>[];

    final result =
        await Navigator.push<(String, String, double, double, List<XFile>)>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationAddPage(
          initialCity: city,
          initialAddress: address,
          initialLat: lat,
          initialLng: lng,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _saveEditedLocation(
      docId: docId,
      city: result.$1,
      address: result.$2,
      lat: result.$3,
      lng: result.$4,
      newPhotos: result.$5,
      existingPhotoUrls: existingPhotoUrls,
    );
  }

  Future<void> _saveEditedLocation({
    required String docId,
    required String city,
    required String address,
    required double lat,
    required double lng,
    required List<XFile> newPhotos,
    required List<String> existingPhotoUrls,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.salonId) return;
    final uid = widget.salonId;

    _showBlockingLoader('Сохраняем локацию…');
    try {
      var photoUrls = existingPhotoUrls;
      if (newPhotos.isNotEmpty) {
        final uploaded = <String>[];
        for (var p = 0; p < newPhotos.length; p++) {
          final url = await _uploadFile(
            File(newPhotos[p].path),
            'autosalons/$uid/locations/$docId/photo_${DateTime.now().millisecondsSinceEpoch}_$p.jpg',
          );
          if (url != null) uploaded.add(url);
        }
        if (uploaded.isNotEmpty) photoUrls = uploaded;
      }

      await _salonRef.collection('locations').doc(docId).set({
        'city': city,
        'address': address,
        'lat': lat,
        'lng': lng,
        'photoUrls': photoUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _loadLocations();
    } catch (e) {
      debugPrint('Failed to update location $docId for salon $uid: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось сохранить локацию: $e')));
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteLocationTapped(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить локацию?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _showBlockingLoader('Удаляем локацию…');
    try {
      await _salonRef.collection('locations').doc(docId).delete();
      await _loadLocations();
    } catch (e) {
      debugPrint(
          'Failed to delete location $docId for salon ${widget.salonId}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось удалить локацию: $e')));
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) setState(() {});
    }
  }

  // ── Owner: add a new car ─────────────────────────────────────────
  Future<void> _addCarTapped() async {
    final result = await Navigator.push<_CarEntry>(
      context,
      MaterialPageRoute(builder: (_) => const _CarFormPage()),
    );
    if (result == null || !mounted) return;
    await _publishNewCar(result);
  }

  Future<void> _publishNewCar(_CarEntry car) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.salonId) return;
    final uid = widget.salonId;

    _showBlockingLoader('Публикуем автомобиль…');
    try {
      final carDoc = FirebaseFirestore.instance.collection('cars').doc();
      final photoUrls = <String>[];
      for (var p = 0; p < car.photos.length; p++) {
        final url = await _uploadFile(
          File(car.photos[p].path),
          'cars/$uid/${carDoc.id}/photo_$p.jpg',
        );
        if (url != null) photoUrls.add(url);
      }
      if (photoUrls.isEmpty) {
        throw Exception('не удалось загрузить фото');
      }
      String? videoUrl;
      if (car.video != null) {
        videoUrl = await _uploadFile(
          File(car.video!.path),
          'cars/$uid/${carDoc.id}/video.mp4',
          timeout: const Duration(seconds: 120),
        );
      }
      await carDoc.set({
        'name': car.name,
        'price': car.price,
        'priceNegotiable': car.priceNegotiable,
        'year': car.year,
        'km': car.km,
        'transmission': car.transmission,
        'fuelType': car.fuelType,
        'engineCapacity': car.engineCapacity,
        'bodyType': car.bodyType,
        'driveType': car.driveType,
        'color': car.color,
        'ownersCount': car.ownersCount,
        'condition': car.condition,
        'description': car.description,
        'photoPaths': photoUrls,
        'videoPath': videoUrl,
        'ownerId': uid,
        'autosalonId': uid,
        'autosalonName': (_salonData?['name'] as String?) ?? '',
        'autosalonLogoUrl': _salonData?['logoUrl'] as String?,
        'isAutosalonCar': true,
        'likesCount': 0,
        'viewsCount': 0,
        'savesCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _loadCars();
    } catch (e) {
      debugPrint('Failed to publish car for salon $uid: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Не удалось опубликовать авто: $e')));
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) setState(() {});
    }
  }

  Future<String?> _uploadFile(
    File file,
    String path, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    try {
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putFile(file).timeout(timeout);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload failed for $path: $e');
      return null;
    }
  }

  void _showBlockingLoader(String label) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.w)),
          child: Padding(
            padding: EdgeInsets.all(6.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                SizedBox(height: 2.h),
                Text(label,
                    style: TextStyle(fontSize: 13.sp, color: Colors.black)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _salonData == null
                ? _notFoundView()
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    child: _content(_salonData!),
                  ),
      ),
    );
  }

  Widget _content(Map<String, dynamic> data) {
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
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(child: _backBar()),
        SliverToBoxAdapter(
          child: _header(
            name: name,
            tagline: tagline,
            years: years,
            logoUrl: logoUrl,
            phone: phone,
            currentData: data,
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
  // Галочка "verified" убрана. Вместо неё, только у владельца, —
  // карандаш редактирования профиля (имя/описание/годы/лого).
  Widget _header({
    required String name,
    required String tagline,
    required String years,
    required String? logoUrl,
    required String phone,
    required Map<String, dynamic> currentData,
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
                          if (_isOwner)
                            GestureDetector(
                              onTap: () => _editSalonProfile(currentData),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: EdgeInsets.only(top: 0.1.h, left: 1.w),
                                child: Container(
                                  padding: EdgeInsets.all(1.3.w),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF2F2F4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.edit_outlined,
                                      size: 1.8.h, color: Colors.black),
                                ),
                              ),
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

  // ── Locations (one-time, loaded into _locationDocs) ────────────────
  // Owner sees an "add location" tile at the end of the row, plus
  // edit/delete icon buttons on every card. Non-owners just browse
  // (tap a card to view full details, exactly as before).
  Widget _locationsSection() {
    if (_locationDocs.isEmpty && !_isOwner) {
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
        itemCount: _locationDocs.length + (_isOwner ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(width: 3.w),
        itemBuilder: (_, i) {
          if (_isOwner && i == _locationDocs.length) {
            return _addLocationTile();
          }
          final doc = _locationDocs[i];
          final d = doc.data();
          final city = (d['city'] as String?) ?? '';
          final address = (d['address'] as String?) ?? '';
          final lat = (d['lat'] as num?)?.toDouble();
          final lng = (d['lng'] as num?)?.toDouble();
          final photoUrls =
              (d['photoUrls'] as List?)?.whereType<String>().toList() ??
                  const <String>[];
          return _locationCard(doc.id, d, city, address, photoUrls, lat, lng);
        },
      ),
    );
  }

  Widget _addLocationTile() {
    return GestureDetector(
      onTap: _addLocationTapped,
      child: Container(
        width: 36.w,
        height: 16.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.5.w),
          border: Border.all(color: const Color(0xFFE2E2E6), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_location_alt_outlined, color: _accent, size: 3.6.h),
            SizedBox(height: 0.8.h),
            Text('Добавить\nлокацию',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10.sp,
                    color: const Color(0xFF8A8A90),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _locationCard(String docId, Map<String, dynamic> data, String city,
      String address, List<String> photoUrls, double? lat, double? lng) {
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
              if (_isOwner) ...[
                Positioned(
                  left: 1.6.w,
                  top: 1.4.h,
                  child: GestureDetector(
                    onTap: () => _editLocationTapped(docId, data),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.all(1.3.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit_outlined,
                          color: Colors.black, size: 1.6.h),
                    ),
                  ),
                ),
                Positioned(
                  right: 2.6.w,
                  top: 1.4.h,
                  child: GestureDetector(
                    onTap: () => _deleteLocationTapped(docId),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.all(1.3.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          color: Colors.black, size: 1.6.h),
                    ),
                  ),
                ),
              ] else
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

  // ── Cars (one-time, loaded into _carDocs) ─────────────────────────
  Widget _carsHeader() {
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
            child: Text('${_carDocs.length}',
                style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFF636366),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _carsGridSliver() {
    if (_carDocs.isEmpty && !_isOwner) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
          child: Text(
            'Автомобили пока не добавлены',
            style: TextStyle(fontSize: 12.sp, color: _muted),
          ),
        ),
      );
    }
    final ownerOffset = _isOwner ? 1 : 0;
    return SliverToBoxAdapter(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 3.w,
          crossAxisSpacing: 3.w,
          childAspectRatio: 0.72,
        ),
        itemCount: _carDocs.length + ownerOffset,
        itemBuilder: (_, i) {
          if (_isOwner && i == 0) return _addCarTile();
          final doc = _carDocs[i - ownerOffset];
          return _carGridTile(doc.id, doc.data());
        },
      ),
    );
  }

  Widget _addCarTile() {
    return GestureDetector(
      onTap: _addCarTapped,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFE2E2E6), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: _accent, size: 4.h),
            SizedBox(height: 1.h),
            Text('Добавить\nавтомобиль',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFF8A8A90),
                    fontWeight: FontWeight.w600)),
          ],
        ),
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

// ══════════════════════════════════════════════════════════════════
// Ниже — тот же набор полей/форм, что и в AutoslonPublishPage._CarEntry
// / _CarFormPage / _SourceSheet / _PressableScale, так что "Добавить
// автомобиль" со страницы статистики выглядит и работает один-в-один
// с публикацией салона.
// ══════════════════════════════════════════════════════════════════

class _CarEntry {
  final String name;
  final String price;
  final String year;
  final String km;
  final String transmission;
  final String fuelType;
  final String engineCapacity;
  final String bodyType;
  final String driveType;
  final String color;
  final String ownersCount;
  final String condition;
  final String description;
  final bool priceNegotiable;
  final List<XFile> photos;
  final XFile? video;

  const _CarEntry({
    required this.name,
    required this.price,
    this.year = '',
    this.km = '',
    this.transmission = '',
    this.fuelType = '',
    this.engineCapacity = '',
    this.bodyType = '',
    this.driveType = '',
    this.color = '',
    this.ownersCount = '',
    this.condition = '',
    this.description = '',
    this.priceNegotiable = false,
    this.photos = const [],
    this.video,
  });
}

class _CarFormPage extends StatefulWidget {
  final _CarEntry? initial;
  const _CarFormPage({this.initial});

  @override
  State<_CarFormPage> createState() => _CarFormPageState();
}

class _CarFormPageState extends State<_CarFormPage> {
  static const _accent = Color(0xFF111111);
  static const _maxPhotos = 4;

  final ImagePicker _picker = ImagePicker();

  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _priceController =
      TextEditingController(text: widget.initial?.price ?? '');
  late final _yearController =
      TextEditingController(text: widget.initial?.year ?? '');
  late final _kmController =
      TextEditingController(text: widget.initial?.km ?? '');
  late final _engineController =
      TextEditingController(text: widget.initial?.engineCapacity ?? '');
  late final _colorController =
      TextEditingController(text: widget.initial?.color ?? '');
  late final _ownersController =
      TextEditingController(text: widget.initial?.ownersCount ?? '');
  late final _descController =
      TextEditingController(text: widget.initial?.description ?? '');

  String? _transmission;
  String? _fuelType;
  String? _bodyType;
  String? _driveType;
  String? _condition;
  bool _priceNegotiable = false;

  final List<XFile> _photos = [];
  XFile? _video;
  VideoPlayerController? _videoPreviewController;
  bool _videoPreviewReady = false;

  static const _transmissions = ['Механика', 'Автомат', 'Робот', 'Вариатор'];
  static const _fuelTypes = ['Бензин', 'Дизель', 'Газ', 'Электро', 'Гибрид'];
  static const _bodyTypes = [
    'Седан', 'Хэтчбек', 'Внедорожник', 'Универсал', 'Купе', 'Минивэн'
  ];
  static const _driveTypes = ['Передний', 'Задний', 'Полный'];
  static const _conditions = [
    'Новый', 'Б/у', 'После аварии', 'Требует ремонта'
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _transmission =
          initial.transmission.isEmpty ? null : initial.transmission;
      _fuelType = initial.fuelType.isEmpty ? null : initial.fuelType;
      _bodyType = initial.bodyType.isEmpty ? null : initial.bodyType;
      _driveType = initial.driveType.isEmpty ? null : initial.driveType;
      _condition = initial.condition.isEmpty ? null : initial.condition;
      _priceNegotiable = initial.priceNegotiable;
      _photos.addAll(initial.photos);
      if (initial.video != null) {
        _video = initial.video;
        _initVideoPreview(initial.video!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _yearController.dispose();
    _kmController.dispose();
    _engineController.dispose();
    _colorController.dispose();
    _ownersController.dispose();
    _descController.dispose();
    _videoPreviewController?.dispose();
    super.dispose();
  }

  Future<void> _initVideoPreview(XFile file) async {
    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
      controller.setLooping(true);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _videoPreviewController = controller;
        _videoPreviewReady = true;
      });
    } catch (_) {
      controller.dispose();
    }
  }

  void _maxReached() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Максимум 4 фото')),
      );

  Future<void> _addPhotoFromCamera() async {
    if (_photos.length >= _maxPhotos) return _maxReached();
    try {
      final x = await _picker.pickImage(
          source: ImageSource.camera, imageQuality: 70);
      if (x != null) setState(() => _photos.add(x));
    } catch (_) {}
  }

  Future<void> _addPhotosFromGallery() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return _maxReached();
    try {
      final list = await _picker.pickMultiImage(imageQuality: 70);
      if (list.isNotEmpty) {
        setState(() => _photos.addAll(list.take(remaining)));
      }
    } catch (_) {}
  }

  void _removePhoto(int i) => setState(() => _photos.removeAt(i));

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final x = await _picker.pickVideo(
          source: source, maxDuration: const Duration(minutes: 2));
      if (x != null) {
        await _videoPreviewController?.dispose();
        _videoPreviewController = null;
        _videoPreviewReady = false;
        setState(() => _video = x);
        await _initVideoPreview(x);
      }
    } catch (_) {}
  }

  void _removeVideo() {
    _videoPreviewController?.dispose();
    _videoPreviewController = null;
    _videoPreviewReady = false;
    setState(() => _video = null);
  }

  void _showPhotoSheet() => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _SourceSheet(
          title: 'Добавить фото',
          cameraLabel: 'Сделать фото',
          galleryLabel: 'Выбрать из галереи',
          onCamera: () {
            Navigator.pop(context);
            _addPhotoFromCamera();
          },
          onGallery: () {
            Navigator.pop(context);
            _addPhotosFromGallery();
          },
        ),
      );

  void _showVideoSheet() => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _SourceSheet(
          title: 'Добавить видео',
          cameraLabel: 'Снять видео',
          galleryLabel: 'Выбрать из галереи',
          onCamera: () {
            Navigator.pop(context);
            _pickVideo(ImageSource.camera);
          },
          onGallery: () {
            Navigator.pop(context);
            _pickVideo(ImageSource.gallery);
          },
        ),
      );

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите модель автомобиля')),
      );
      return;
    }
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одно фото')),
      );
      return;
    }
    Navigator.pop(
      context,
      _CarEntry(
        name: name,
        price: _priceController.text.trim(),
        year: _yearController.text.trim(),
        km: _kmController.text.trim(),
        transmission: _transmission ?? '',
        fuelType: _fuelType ?? '',
        engineCapacity: _engineController.text.trim(),
        bodyType: _bodyType ?? '',
        driveType: _driveType ?? '',
        color: _colorController.text.trim(),
        ownersCount: _ownersController.text.trim(),
        condition: _condition ?? '',
        description: _descController.text.trim(),
        priceNegotiable: _priceNegotiable,
        photos: List<XFile>.from(_photos),
        video: _video,
      ),
    );
  }

  InputDecoration _decoration({String? hint, IconData? icon}) {
    OutlineInputBorder b(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(4.w),
          borderSide: BorderSide(color: c, width: 1.4),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(fontSize: 12.5.sp, color: const Color(0xFFB4B4BA)),
      filled: true,
      fillColor: const Color(0xFFF8F8FA),
      prefixIcon: icon != null
          ? Icon(icon, color: const Color(0xFF8A8A90), size: 2.2.h)
          : null,
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
      enabledBorder: b(const Color(0xFFEAEAEE)),
      focusedBorder: b(_accent),
    );
  }

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(left: 1.w, bottom: 0.9.h),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6A6A70),
          ),
        ),
      );

  Widget _section(String title) => Padding(
        padding: EdgeInsets.only(bottom: 1.6.h, top: 1.h),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: _accent,
            letterSpacing: -0.3,
          ),
        ),
      );

  Widget _sectionTitle(String title, String trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: _accent,
                letterSpacing: -0.3)),
        if (trailing.isNotEmpty)
          Text(trailing,
              style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFFB4B4BA),
                  fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          cursorColor: _accent,
          style: TextStyle(
              fontSize: 14.sp, fontWeight: FontWeight.w600, color: _accent),
          decoration: _decoration(hint: hint, icon: icon),
        ),
        SizedBox(height: 2.h),
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF8A8A90)),
          borderRadius: BorderRadius.circular(4.w),
          style: TextStyle(
              fontSize: 14.sp, fontWeight: FontWeight.w600, color: _accent),
          hint: Text('Выберите',
              style: TextStyle(
                  fontSize: 13.sp, color: const Color(0xFFB4B4BA))),
          decoration: _decoration(icon: icon),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
        SizedBox(height: 2.h),
      ],
    );
  }

  Widget _negotiableSwitch() {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: GestureDetector(
        onTap: () => setState(() => _priceNegotiable = !_priceNegotiable),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.6.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F4),
            borderRadius: BorderRadius.circular(4.w),
          ),
          child: Row(
            children: [
              Icon(Icons.sell_outlined, color: _accent, size: 2.4.h),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  'Цена обсуждается (торг)',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _accent,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _priceNegotiable,
                activeColor: _accent,
                onChanged: (v) => setState(() => _priceNegotiable = v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoWrap() {
    final tile = 26.w;
    return Wrap(
      spacing: 3.w,
      runSpacing: 3.w,
      children: [
        if (_photos.length < _maxPhotos)
          _PressableScale(
            onTap: _showPhotoSheet,
            child: Container(
              width: tile,
              height: tile,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.w),
                border:
                    Border.all(color: const Color(0xFFE2E2E6), width: 1.4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: _accent, size: 3.2.h),
                  SizedBox(height: 0.8.h),
                  Text('Добавить',
                      style: TextStyle(
                          fontSize: 10.sp,
                          color: const Color(0xFF8A8A90),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        for (int i = 0; i < _photos.length; i++) _photoThumb(i, tile),
      ],
    );
  }

  Widget _photoThumb(int i, double tile) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4.w),
          child: Image.file(File(_photos[i].path),
              width: tile, height: tile, fit: BoxFit.cover),
        ),
        Positioned(
          top: 1.w,
          right: 1.w,
          child: GestureDetector(
            onTap: () => _removePhoto(i),
            child: Container(
              padding: EdgeInsets.all(0.6.w),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle),
              child: Icon(Icons.close, color: Colors.white, size: 1.8.h),
            ),
          ),
        ),
        if (i == 0)
          Positioned(
            left: 1.w,
            bottom: 1.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2.w)),
              child: Text('Обложка',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  Widget _videoArea() {
    if (_video == null) {
      return _PressableScale(
        onTap: _showVideoSheet,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 3.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.w),
            border: Border.all(color: const Color(0xFFE2E2E6), width: 1.4),
          ),
          child: Column(
            children: [
              Icon(Icons.videocam_outlined, color: _accent, size: 3.6.h),
              SizedBox(height: 1.h),
              Text('Добавить видео',
                  style: TextStyle(
                      fontSize: 13.sp,
                      color: _accent,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 0.4.h),
              Text('Обзор со всех сторон · до 2 минут',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.sp, color: const Color(0xFF9A9AA0))),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFE2E2E6), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: _videoPreviewReady
                ? _videoPreviewController!.value.aspectRatio
                : 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3.w),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_videoPreviewReady)
                    GestureDetector(
                      onTap: () => setState(() {
                        final c = _videoPreviewController!;
                        c.value.isPlaying ? c.pause() : c.play();
                      }),
                      child: VideoPlayer(_videoPreviewController!),
                    )
                  else
                    Container(
                      color: const Color(0xFF111111),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                  if (_videoPreviewReady)
                    IgnorePointer(
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _videoPreviewController!.value.isPlaying
                              ? 0.0
                              : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: 13.w,
                            height: 13.w,
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle),
                            child: Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 7.w),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: _accent, size: 2.2.h),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(_video!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF6A6A70),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          SizedBox(height: 1.4.h),
          Row(
            children: [
              Expanded(
                child: _PressableScale(
                  onTap: _showVideoSheet,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 1.4.h),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F4),
                        borderRadius: BorderRadius.circular(3.w)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.autorenew_rounded,
                            size: 2.h, color: _accent),
                        SizedBox(width: 2.w),
                        Text('Заменить',
                            style: TextStyle(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w700,
                                color: _accent)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _PressableScale(
                  onTap: _removeVideo,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 1.4.h),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F4),
                        borderRadius: BorderRadius.circular(3.w)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline,
                            size: 2.h, color: const Color(0xFF8A8A90)),
                        SizedBox(width: 2.w),
                        Text('Удалить',
                            style: TextStyle(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF8A8A90))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return _PressableScale(
      onTap: _submit,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 2.2.h),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(4.w),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.initial == null ? 'Добавить автомобиль' : 'Сохранить',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(5.w, 0.5.h, 5.w, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.only(right: 3.w),
                      child:
                          Icon(Icons.arrow_back, color: _accent, size: 3.2.h),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.initial == null
                          ? 'Добавить автомобиль'
                          : 'Редактировать автомобиль',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: _accent,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(5.w, 2.5.h, 5.w, 2.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(
                        'Фотографии', '${_photos.length}/$_maxPhotos'),
                    SizedBox(height: 1.5.h),
                    _photoWrap(),
                    SizedBox(height: 3.h),
                    _sectionTitle('Видео', _video == null ? '' : '1'),
                    SizedBox(height: 1.5.h),
                    _videoArea(),
                    SizedBox(height: 3.h),
                    _section('Основное'),
                    _textField(
                      label: 'Марка и модель',
                      controller: _nameController,
                      hint: 'Toyota Camry',
                      icon: Icons.directions_car_outlined,
                    ),
                    _textField(
                      label: 'Цена, \$',
                      controller: _priceController,
                      hint: '15 000',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                    ),
                    _negotiableSwitch(),
                    _section('Характеристики'),
                    Row(
                      children: [
                        Expanded(
                          child: _textField(
                            label: 'Год',
                            controller: _yearController,
                            hint: '2018',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: _textField(
                            label: 'Пробег, км',
                            controller: _kmController,
                            hint: '85 000',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    _dropdownField(
                      label: 'Коробка передач',
                      value: _transmission,
                      items: _transmissions,
                      icon: Icons.settings_outlined,
                      onChanged: (v) => setState(() => _transmission = v),
                    ),
                    _dropdownField(
                      label: 'Тип топлива',
                      value: _fuelType,
                      items: _fuelTypes,
                      icon: Icons.local_gas_station_outlined,
                      onChanged: (v) => setState(() => _fuelType = v),
                    ),
                    _dropdownField(
                      label: 'Тип кузова',
                      value: _bodyType,
                      items: _bodyTypes,
                      icon: Icons.airport_shuttle_outlined,
                      onChanged: (v) => setState(() => _bodyType = v),
                    ),
                    _dropdownField(
                      label: 'Привод',
                      value: _driveType,
                      items: _driveTypes,
                      icon: Icons.all_inclusive_outlined,
                      onChanged: (v) => setState(() => _driveType = v),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _textField(
                            label: 'Объём, л',
                            controller: _engineController,
                            hint: '2.0',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: _textField(
                            label: 'Цвет',
                            controller: _colorController,
                            hint: 'Чёрный',
                          ),
                        ),
                      ],
                    ),
                    _section('Состояние и история'),
                    _dropdownField(
                      label: 'Состояние',
                      value: _condition,
                      items: _conditions,
                      icon: Icons.health_and_safety_outlined,
                      onChanged: (v) => setState(() => _condition = v),
                    ),
                    _textField(
                      label: 'Количество владельцев',
                      controller: _ownersController,
                      hint: '1',
                      icon: Icons.groups_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    _label('Описание'),
                    TextField(
                      controller: _descController,
                      maxLines: 5,
                      maxLength: 1000,
                      cursorColor: _accent,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: _accent,
                        height: 1.4,
                      ),
                      decoration: _decoration(
                          hint:
                              'Расскажите о состоянии, истории обслуживания, комплектации...'),
                    ),
                    SizedBox(height: 2.h),
                    _submitButton(),
                    SizedBox(height: 2.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceSheet extends StatelessWidget {
  final String title, cameraLabel, galleryLabel;
  final VoidCallback onCamera, onGallery;
  const _SourceSheet({
    required this.title,
    required this.cameraLabel,
    required this.galleryLabel,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 2.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12.w,
                height: 0.6.h,
                decoration: BoxDecoration(
                    color: const Color(0xFFD8D8DE),
                    borderRadius: BorderRadius.circular(2.h)),
              ),
              SizedBox(height: 2.h),
              Text(title,
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.black)),
              SizedBox(height: 2.h),
              _option(Icons.photo_camera_outlined, cameraLabel, onCamera),
              SizedBox(height: 1.4.h),
              _option(Icons.photo_library_outlined, galleryLabel, onGallery),
              SizedBox(height: 0.6.h),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(1.5.h),
                  child: Text('Отмена',
                      style: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFF9A9AA0),
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F4),
          borderRadius: BorderRadius.circular(4.w),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF111111), size: 2.8.h),
            SizedBox(width: 3.w),
            Text(label,
                style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
          ],
        ),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  const _PressableScale({
    required this.child,
    required this.onTap,
    this.scale = 0.97,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}