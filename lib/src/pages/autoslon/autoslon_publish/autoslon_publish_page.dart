import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_app/src/pages/autoslon/location/location_add_page.dart';
import 'package:new_app/src/pages/autoslon/permission/publish_permission.dart';
import 'package:new_app/src/pages/pages.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class AutoslonPublishPage extends StatefulWidget {
  const AutoslonPublishPage({Key? key}) : super(key: key);

  @override
  State<AutoslonPublishPage> createState() => _AutoslonPublishPageState();
}

// ── Data models ──────────────────────────────────────────────────
class _SalonLocation {
  final String city;
  final String address;
  final IconData icon;
  final List<Color> gradient;
  final double lat;
  final double lng;
  // Up to 2 photos of this specific location (building, sign, etc.)
  final List<XFile> photos;

  const _SalonLocation({
    required this.city,
    required this.address,
    required this.icon,
    required this.gradient,
    this.lat = 0,
    this.lng = 0,
    this.photos = const [],
  });

  _SalonLocation copyWith({
    String? city,
    String? address,
    double? lat,
    double? lng,
    List<XFile>? photos,
  }) {
    return _SalonLocation(
      city: city ?? this.city,
      address: address ?? this.address,
      icon: icon,
      gradient: gradient,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      photos: photos ?? this.photos,
    );
  }
}

class _CarEntry {
  final String name;
  final String price;
  final XFile? photo;
  const _CarEntry({required this.name, required this.price, this.photo});
}

class _AutoslonPublishPageState extends State<AutoslonPublishPage>
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFF111111);
  static const _maxPhotos = 9;
  static const _maxMedia = 10;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];
  XFile? _video;

  final _descController = TextEditingController();
  final _phoneController = TextEditingController();

  String _salonName = '';
  String _salonTagline = '';
  String _salonYears = '';
  XFile? _salonLogo;

  final List<_SalonLocation> _locations = [];

  static const List<List<Color>> _locationGradients = [
    [Color(0xFF2B2B2E), Color(0xFF111113)],
    [Color(0xFF3A3A3D), Color(0xFF1A1A1C)],
    [Color(0xFF24262B), Color(0xFF0E0F11)],
    [Color(0xFF35303A), Color(0xFF14111A)],
    [Color(0xFF2E3430), Color(0xFF10130F)],
  ];

  List<Color> _nextLocationGradient() =>
      _locationGradients[_locations.length % _locationGradients.length];

  final List<_CarEntry> _cars = [];

  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _descController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Media ─────────────────────────────────────────────────────
  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _addPhotoFromCamera() async {
    if (_photos.length >= _maxPhotos) {
      _showSnack('Максимум $_maxMedia файлов');
      return;
    }
    try {
      final x = await _picker.pickImage(
          source: ImageSource.camera, imageQuality: 70);
      if (x != null) setState(() => _photos.add(x));
    } catch (_) {}
  }

  Future<void> _addPhotosFromGallery() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) {
      _showSnack('Максимум $_maxMedia файлов');
      return;
    }
    try {
      final list = await _picker.pickMultiImage(imageQuality: 70);
      if (list.isNotEmpty) {
        setState(() => _photos.addAll(list.take(remaining)));
      }
    } catch (_) {}
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final x = await _picker.pickVideo(
          source: source, maxDuration: const Duration(minutes: 2));
      if (x != null) setState(() => _video = x);
    } catch (_) {}
  }

  void _removePhoto(int i) => setState(() => _photos.removeAt(i));
  void _removeVideo() => setState(() => _video = null);

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

  // ── Locations ─────────────────────────────────────────────────
  /// Opens LocationAddPage to add a brand-new location.
  Future<void> _addLocationTapped() async {
    final result =
        await Navigator.push<(String, String, double, double, List<XFile>)>(
      context,
      MaterialPageRoute(builder: (_) => const LocationAddPage()),
    );
    if (result == null || !mounted) return;
    setState(() {
      _locations.add(_SalonLocation(
        city: result.$1,
        address: result.$2,
        icon: Icons.location_city,
        gradient: _nextLocationGradient(),
        lat: result.$3,
        lng: result.$4,
        photos: result.$5,
      ));
    });
  }

  /// Opens LocationAddPage pre-filled so the user can edit an existing one.
  Future<void> _editLocationTapped(int index) async {
    final loc = _locations[index];
    final result =
        await Navigator.push<(String, String, double, double, List<XFile>)>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationAddPage(
          initialCity: loc.city,
          initialAddress: loc.address,
          initialLat: loc.lat,
          initialLng: loc.lng,
          initialPhotos: List<XFile>.from(loc.photos),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _locations[index] = _locations[index].copyWith(
        city: result.$1,
        address: result.$2,
        lat: result.$3,
        lng: result.$4,
        photos: result.$5,
      );
    });
  }

  void _removeLocation(int index) =>
      setState(() => _locations.removeAt(index));

  // ── Salon profile ─────────────────────────────────────────────
  Future<void> _editSalonTapped() async {
    final result = await Navigator.push<(String, String, String, XFile?)>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEdit(
          initialName: _salonName,
          initialTagline: _salonTagline,
          initialYears: _salonYears,
          initialLogo: _salonLogo,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _salonName = result.$1;
      _salonTagline = result.$2;
      _salonYears = result.$3;
      _salonLogo = result.$4;
    });
  }

  // ── Cars ──────────────────────────────────────────────────────
  Future<void> _openAddCarSheet() async {
    final result = await showModalBottomSheet<_CarEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CarFormSheet(),
    );
    if (result != null) setState(() => _cars.add(result));
  }

  Future<void> _openEditCarSheet(int i) async {
    final result = await showModalBottomSheet<_CarEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CarFormSheet(initial: _cars[i]),
    );
    if (result != null) setState(() => _cars[i] = result);
  }

  void _removeCar(int i) => setState(() => _cars.removeAt(i));

  // ── Publish ───────────────────────────────────────────────────
  Future<void> _publish() async {
    if (_photos.isEmpty) {
      _showSnack('Добавьте хотя бы одно фото');
      return;
    }
    final confirmed = await showPublishConfirmDialog(context);
    if (!confirmed || !mounted) return;
    try {
      await PublishPermissions.consume(PublishType.autoslon);
    } catch (_) {}
    if (!mounted) return;
    _showSnack('Объявление опубликовано 🎉');
    Navigator.pop(context);
  }

  // ── Animation ─────────────────────────────────────────────────
  Widget _anim(int order, Widget child) {
    final start = (order * 0.06).clamp(0.0, 0.7);
    final curved = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (_, c) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * 2.5.h), child: c),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    int order = 0;
    Widget a(Widget c) => _anim(order++, c);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F4),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(5.w, 0.5.h, 5.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.only(right: 3.w),
                          child: Icon(Icons.arrow_back,
                              color: Colors.black, size: 3.2.h),
                        ),
                      ),
                      Expanded(
                        child: a(Text(
                          'Публикация',
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: -0.5,
                          ),
                        )),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  a(Text(
                    'Расскажите о вашем автосалоне. Покажите, что делает его особенным.',
                    style: TextStyle(
                        fontSize: 13.sp, color: const Color(0xFF9A9AA0)),
                  )),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(5.w, 3.h, 5.w, 3.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    a(_salonCard()),
                    SizedBox(height: 3.h),
                    a(_sectionTitle('Наши локации',
                        _locations.isEmpty ? '' : '${_locations.length}')),
                    SizedBox(height: 1.5.h),
                    a(_locationsRow()),
                    SizedBox(height: 3.5.h),
                    a(_bigSectionTitle('Расскажите о вашем автосалоне')),
                    SizedBox(height: 2.h),
                    a(_sectionTitle('Фото и видео', 'До $_maxMedia файлов')),
                    SizedBox(height: 1.5.h),
                    a(_mediaWrap()),
                    SizedBox(height: 3.h),
                    a(_sectionTitle('Опишите ваш автосалон', '')),
                    SizedBox(height: 1.5.h),
                    a(_descField()),
                    SizedBox(height: 3.h),
                    a(_sectionTitle('Контакты', '')),
                    SizedBox(height: 1.5.h),
                    a(_phoneField()),
                    SizedBox(height: 3.5.h),
                    a(_sectionTitle('Наши автомобили', '${_cars.length}')),
                    SizedBox(height: 1.5.h),
                    a(_carsRow()),
                    SizedBox(height: 3.5.h),
                    a(_publishButton()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Salon card ────────────────────────────────────────────────
  Widget _salonCard() {
    return _salonName.trim().isEmpty ? _salonEmptyCard() : _salonFilledCard();
  }

  Widget _salonEmptyCard() {
    return _PressableScale(
      onTap: _editSalonTapped,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFEAEAEE), width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16.w,
              height: 16.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F1EC),
                shape: BoxShape.circle,
                border:
                    Border.all(color: const Color(0xFFE7DFD6), width: 1.2),
              ),
              child: Icon(Icons.storefront_outlined,
                  color: const Color(0xFFC0392B), size: 4.h),
            ),
            SizedBox(height: 2.h),
            Text('Заполните профиль автосалона',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black)),
            SizedBox(height: 0.6.h),
            Text('Укажите название, описание и сколько лет вы на рынке',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF9A9AA0),
                    height: 1.4)),
            SizedBox(height: 2.2.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.2.h),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 1.8.h, color: Colors.white),
                  SizedBox(width: 1.5.w),
                  Text('Заполнить',
                      style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _salonFilledCard() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFEAEAEE), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 13.w,
                height: 13.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F1EC),
                  borderRadius: BorderRadius.circular(3.5.w),
                  border:
                      Border.all(color: const Color(0xFFE7DFD6), width: 1.2),
                ),
                child: _salonLogo == null
                    ? Icon(Icons.directions_car_filled,
                        color: const Color(0xFFC0392B), size: 3.4.h)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(3.5.w),
                        child: Image.file(File(_salonLogo!.path),
                            width: 13.w, height: 13.w, fit: BoxFit.cover),
                      ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_salonName,
                        style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.black)),
                    SizedBox(height: 0.4.h),
                    Text(
                        _salonTagline.isEmpty
                            ? 'Добавьте описание салона'
                            : _salonTagline,
                        style: TextStyle(
                            fontSize: 11.5.sp,
                            color: const Color(0xFF9A9AA0),
                            height: 1.3)),
                  ],
                ),
              ),
              SizedBox(width: 2.w),
              _PressableScale(
                onTap: _editSalonTapped,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.9.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F4),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 1.8.h, color: Colors.black),
                      SizedBox(width: 1.w),
                      Text('Редактировать',
                          style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.black)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.5.h),
          Container(height: 1, color: const Color(0xFFF0F0F2)),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(child: _statTile('${_cars.length}', 'Автомобилей')),
              Expanded(child: _statTile('${_locations.length}', 'Локаций')),
              Expanded(
                  child: _statTile(
                      _salonYears.isEmpty ? '—' : _salonYears, 'На рынке')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black)),
        SizedBox(height: 0.3.h),
        Text(label,
            style: TextStyle(
                fontSize: 10.5.sp, color: const Color(0xFF9A9AA0))),
      ],
    );
  }

  // ── Locations row ─────────────────────────────────────────────
  Widget _locationsRow() {
    if (_locations.isEmpty) return _locationsEmptyCard();
    return SizedBox(
      height: 17.h, // slightly taller to fit photo strip
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _locations.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: 3.w),
        itemBuilder: (_, i) => i == _locations.length
            ? _addLocationTile()
            : _locationCard(_locations[i], index: i),
      ),
    );
  }

  Widget _locationsEmptyCard() {
    return _PressableScale(
      onTap: _addLocationTapped,
      child: Container(
        width: double.infinity,
        height: 17.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFE2E2E6), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_location_alt_outlined, color: _accent, size: 4.h),
            SizedBox(height: 1.h),
            Text('Добавить локацию',
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
            SizedBox(height: 0.3.h),
            Text('Покажите клиентам, где вас найти',
                style: TextStyle(
                    fontSize: 11.sp, color: const Color(0xFF9A9AA0))),
          ],
        ),
      ),
    );
  }

  Widget _addLocationTile() {
    return _PressableScale(
      onTap: _addLocationTapped,
      child: Container(
        width: 36.w,
        height: 17.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFE2E2E6), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_location_alt_outlined, color: _accent, size: 3.2.h),
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

  /// Location card — shows up to 2 photos as background if available.
  /// Edit (pencil) and delete (×) buttons overlay the top corners.
  Widget _locationCard(_SalonLocation loc, {required int index}) {
    final hasPhotos = loc.photos.isNotEmpty;

    return Container(
      width: 44.w,
      height: 17.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.w),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.w),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background: photo(s) or gradient ────────────────
            if (hasPhotos)
              // If 2 photos: split left/right; if 1: full cover
              loc.photos.length == 1
                  ? Image.file(File(loc.photos[0].path),
                      fit: BoxFit.cover)
                  : Row(
                      children: [
                        Expanded(
                          child: Image.file(File(loc.photos[0].path),
                              height: double.infinity, fit: BoxFit.cover),
                        ),
                        Container(width: 1, color: Colors.black26),
                        Expanded(
                          child: Image.file(File(loc.photos[1].path),
                              height: double.infinity, fit: BoxFit.cover),
                        ),
                      ],
                    )
            else
              // Gradient fallback
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: loc.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(loc.icon,
                      color: Colors.white.withOpacity(0.30), size: 5.h),
                ),
              ),

            // Dim overlay so text is always readable
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(hasPhotos ? 0.12 : 0.0),
                    Colors.black.withOpacity(0.60),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // ── Edit button (top-left) ───────────────────────────
            Positioned(
              top: 1.6.w,
              left: 1.6.w,
              child: GestureDetector(
                onTap: () => _editLocationTapped(index),
                child: Container(
                  padding: EdgeInsets.all(1.4.w),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      shape: BoxShape.circle),
                  child: Icon(Icons.edit_outlined,
                      color: Colors.black, size: 1.8.h),
                ),
              ),
            ),

            // ── Delete button (top-right) ────────────────────────
            Positioned(
              top: 1.6.w,
              right: 1.6.w,
              child: GestureDetector(
                onTap: () => _removeLocation(index),
                child: Container(
                  padding: EdgeInsets.all(1.4.w),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      shape: BoxShape.circle),
                  child: Icon(Icons.close,
                      color: Colors.black, size: 1.8.h),
                ),
              ),
            ),

            // ── City + address (bottom) ──────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(2.8.w, 0, 2.8.w, 1.6.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loc.city,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(
                                  blurRadius: 4,
                                  color: Colors.black.withOpacity(0.5))
                            ])),
                    SizedBox(height: 0.2.h),
                    Text(loc.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 10.sp,
                            shadows: [
                              Shadow(
                                  blurRadius: 4,
                                  color: Colors.black.withOpacity(0.5))
                            ])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section titles ────────────────────────────────────────────
  Widget _bigSectionTitle(String title) {
    return Text(title,
        style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: -0.3));
  }

  Widget _sectionTitle(String title, String trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black,
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

  // ── General media ─────────────────────────────────────────────
  Widget _mediaWrap() {
    final tile = 26.w;
    final canAddPhoto = _photos.length < _maxPhotos;
    return Wrap(
      spacing: 3.w,
      runSpacing: 3.w,
      children: [
        for (int i = 0; i < _photos.length; i++) _photoThumb(i, tile),
        if (canAddPhoto)
          _addTile(tile, Icons.add_a_photo_outlined, 'Добавить\nфото',
              _showPhotoSheet),
        _video == null
            ? _addTile(tile, Icons.videocam_outlined, 'Добавить\nвидео',
                _showVideoSheet)
            : _videoThumb(tile),
      ],
    );
  }

  Widget _addTile(
      double tile, IconData icon, String label, VoidCallback onTap) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        width: tile,
        height: tile,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFE2E2E6), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _accent, size: 3.2.h),
            SizedBox(height: 0.8.h),
            Text(label,
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
                  color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
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

  Widget _videoThumb(double tile) {
    return Stack(
      children: [
        Container(
          width: tile,
          height: tile,
          decoration: BoxDecoration(
              color: _accent, borderRadius: BorderRadius.circular(4.w)),
          child:
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 4.h),
        ),
        Positioned(
          top: 1.w,
          right: 1.w,
          child: GestureDetector(
            onTap: _removeVideo,
            child: Container(
              padding: EdgeInsets.all(0.6.w),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
              child: Icon(Icons.close, color: Colors.white, size: 1.8.h),
            ),
          ),
        ),
      ],
    );
  }

  Widget _descField() {
    return TextField(
      controller: _descController,
      maxLines: 5,
      maxLength: 1000,
      cursorColor: _accent,
      style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: Colors.black,
          height: 1.4),
      decoration: _decoration(
          'Расскажите об автосалоне, его истории, преимуществах...'),
    );
  }

  Widget _phoneField() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      cursorColor: _accent,
      style: TextStyle(
          fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.black),
      decoration: _decoration('+996 ___ ______', icon: Icons.phone_outlined),
    );
  }

  // ── Cars list ─────────────────────────────────────────────────
  Widget _carsRow() {
    final tile = 30.w;
    final imageHeight = tile * 0.7;
    return SizedBox(
      height: imageHeight + 7.5.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (int i = 0; i < _cars.length; i++)
            Padding(
              padding: EdgeInsets.only(right: 3.w),
              child: _carCard(_cars[i], i, tile, imageHeight),
            ),
          _addCarTile(tile, imageHeight),
        ],
      ),
    );
  }

  Widget _carCard(_CarEntry car, int i, double tile, double imageHeight) {
    return Container(
      width: tile,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFE2E2E6), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4.w),
                    topRight: Radius.circular(4.w)),
                child: car.photo != null
                    ? Image.file(File(car.photo!.path),
                        width: tile, height: imageHeight, fit: BoxFit.cover)
                    : Container(
                        width: tile,
                        height: imageHeight,
                        color: const Color(0xFFF2F2F4),
                        child: Icon(Icons.directions_car_outlined,
                            color: const Color(0xFFB4B4BA), size: 4.h),
                      ),
              ),
              Positioned(
                top: 1.w,
                left: 1.w,
                child: GestureDetector(
                  onTap: () => _openEditCarSheet(i),
                  child: Container(
                    padding: EdgeInsets.all(0.6.w),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle),
                    child: Icon(Icons.edit, color: Colors.white, size: 1.5.h),
                  ),
                ),
              ),
              Positioned(
                top: 1.w,
                right: 1.w,
                child: GestureDetector(
                  onTap: () => _removeCar(i),
                  child: Container(
                    padding: EdgeInsets.all(0.6.w),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle),
                    child: Icon(Icons.close, color: Colors.white, size: 1.6.h),
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => _openEditCarSheet(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(2.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(car.name.isEmpty ? 'Без названия' : car.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black)),
                  SizedBox(height: 0.2.h),
                  Text(car.price.isEmpty ? '—' : car.price,
                      style: TextStyle(
                          fontSize: 11.sp,
                          color: const Color(0xFF9A9AA0),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addCarTile(double tile, double imageHeight) {
    return _PressableScale(
      onTap: _openAddCarSheet,
      child: Container(
        width: tile,
        height: imageHeight + 7.5.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFE2E2E6), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: _accent, size: 3.2.h),
            SizedBox(height: 0.8.h),
            Text('Добавить\nавтомобиль',
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

  Widget _publishButton() {
    return _PressableScale(
      onTap: _publish,
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
                offset: const Offset(0, 8)),
          ],
        ),
        alignment: Alignment.center,
        child: Text('Опубликовать объявление',
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2)),
      ),
    );
  }

  InputDecoration _decoration(String hint, {IconData? icon}) {
    OutlineInputBorder b(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(4.w),
          borderSide: BorderSide(color: c, width: 1.4),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontSize: 12.5.sp,
          color: const Color(0xFFB4B4BA),
          fontWeight: FontWeight.w400),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: icon != null
          ? Icon(icon, color: const Color(0xFF8A8A90), size: 2.4.h)
          : null,
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      enabledBorder: b(const Color(0xFFEAEAEE)),
      focusedBorder: b(_accent),
    );
  }
}

// ── Car form sheet ────────────────────────────────────────────────
class _CarFormSheet extends StatefulWidget {
  final _CarEntry? initial;
  const _CarFormSheet({this.initial});

  @override
  State<_CarFormSheet> createState() => _CarFormSheetState();
}

class _CarFormSheetState extends State<_CarFormSheet> {
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _priceController =
      TextEditingController(text: widget.initial?.price ?? '');
  final ImagePicker _picker = ImagePicker();
  XFile? _photo;

  @override
  void initState() {
    super.initState();
    _photo = widget.initial?.photo;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final x = await _picker.pickImage(source: source, imageQuality: 70);
      if (x != null) setState(() => _photo = x);
    } catch (_) {}
  }

  void _showPhotoSheet() => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _SourceSheet(
          title: 'Фото автомобиля',
          cameraLabel: 'Сделать фото',
          galleryLabel: 'Выбрать из галереи',
          onCamera: () {
            Navigator.pop(context);
            _pickPhoto(ImageSource.camera);
          },
          onGallery: () {
            Navigator.pop(context);
            _pickPhoto(ImageSource.gallery);
          },
        ),
      );

  void _submit() {
    final name = _nameController.text.trim();
    final price = _priceController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите модель автомобиля')),
      );
      return;
    }
    Navigator.pop(context, _CarEntry(name: name, price: price, photo: _photo));
  }

  InputDecoration _decoration(String hint) {
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
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
      enabledBorder: b(const Color(0xFFEAEAEE)),
      focusedBorder: b(const Color(0xFF111111)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 12.w,
                    height: 0.6.h,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD8D8DE),
                        borderRadius: BorderRadius.circular(2.h)),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                    widget.initial == null
                        ? 'Добавить автомобиль'
                        : 'Редактировать автомобиль',
                    style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.black)),
                SizedBox(height: 2.h),
                GestureDetector(
                  onTap: _showPhotoSheet,
                  child: Container(
                    width: double.infinity,
                    height: 14.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F4),
                      borderRadius: BorderRadius.circular(4.w),
                      border: Border.all(
                          color: const Color(0xFFE2E2E6), width: 1.4),
                    ),
                    child: _photo == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  color: const Color(0xFF111111), size: 3.h),
                              SizedBox(height: 0.6.h),
                              Text('Фото автомобиля',
                                  style: TextStyle(
                                      fontSize: 12.sp,
                                      color: const Color(0xFF8A8A90),
                                      fontWeight: FontWeight.w600)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(4.w),
                            child: Image.file(File(_photo!.path),
                                width: double.infinity,
                                height: 14.h,
                                fit: BoxFit.cover),
                          ),
                  ),
                ),
                SizedBox(height: 2.h),
                TextField(
                  controller: _nameController,
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black),
                  decoration:
                      _decoration('Модель, напр. Toyota Camry 2023'),
                ),
                SizedBox(height: 1.5.h),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black),
                  decoration: _decoration('Цена, напр. 25 000 \$'),
                ),
                SizedBox(height: 2.5.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      padding: EdgeInsets.symmetric(vertical: 1.8.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.w)),
                    ),
                    child: Text(
                        widget.initial == null ? 'Добавить' : 'Сохранить',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Source sheet (camera / gallery) ──────────────────────────────
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

// ── Press-to-scale wrapper ────────────────────────────────────────
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