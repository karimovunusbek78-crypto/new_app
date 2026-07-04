import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:responsive_sizer/responsive_sizer.dart';

class _KgCity {
  final String name;
  final LatLng coords;
  final double zoom;
  const _KgCity(this.name, this.coords, {this.zoom = 12});
}

const _kgOverview = LatLng(41.20438, 74.766098);
const _kgOverviewZoom = 6.2;

const List<_KgCity> _kgCities = [
  _KgCity('Бишкек', LatLng(42.8746, 74.5698)),
  _KgCity('Ош', LatLng(40.5283, 72.7985)),
  _KgCity('Каракол', LatLng(42.4907, 78.3936), zoom: 12.5),
  _KgCity('Жалал-Абад', LatLng(40.9333, 72.9700), zoom: 12.5),
  _KgCity('Талас', LatLng(42.5226, 72.2419), zoom: 12.5),
  _KgCity('Нарын', LatLng(41.4287, 75.9908), zoom: 12.5),
  _KgCity('Баткен', LatLng(40.0606, 70.8189), zoom: 12.5),
];

enum _Step { intro, map }

/// Add or edit a salon location.
///
/// Pass [initialCity], [initialAddress], [initialLat], [initialLng],
/// and [initialPhotos] to pre-fill when editing an existing location.
///
/// Returns `(city, address, lat, lng, photos)` on pop.
/// [photos] is a List<XFile> with 0–2 items.
class LocationAddPage extends StatefulWidget {
  final String initialCity;
  final String initialAddress;
  final double initialLat;
  final double initialLng;
  final List<XFile> initialPhotos;

  const LocationAddPage({
    Key? key,
    this.initialCity = '',
    this.initialAddress = '',
    this.initialLat = 0,
    this.initialLng = 0,
    this.initialPhotos = const [],
  }) : super(key: key);

  @override
  State<LocationAddPage> createState() => _LocationAddPageState();
}

class _LocationAddPageState extends State<LocationAddPage>
    with TickerProviderStateMixin {
  static const _accent = Color(0xFF111111);
  static const _maxLocPhotos = 2;

  bool get _isEditing => widget.initialLat != 0 || widget.initialLng != 0;

  _Step _step = _Step.intro;

  final MapController _mapController = MapController();
  bool _mapReady = false;

  late final AnimationController _cameraAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addListener(_onCameraTick);
  Animation<double>? _latAnim, _lngAnim, _zoomAnim;

  LatLng? _selectedPoint;
  String? _activeCity;
  String _resolvedCity = '';
  late final TextEditingController _addressController;
  bool _geocoding = false;
  bool _locating = false;

  // Location photos — max 2
  final List<XFile> _locPhotos = [];
  final ImagePicker _picker = ImagePicker();

  // Search
  final _searchController = TextEditingController();
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showResults = false;

  late final AnimationController _introController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress);
    _resolvedCity = widget.initialCity;
    _locPhotos.addAll(widget.initialPhotos);
    if (_isEditing) {
      _selectedPoint = LatLng(widget.initialLat, widget.initialLng);
      _step = _Step.map;
    }
  }

  @override
  void dispose() {
    _cameraAnim.dispose();
    _introController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Camera animation ─────────────────────────────────────────
  void _onCameraTick() {
    if (_latAnim == null || !_mapReady) return;
    _mapController.move(
        LatLng(_latAnim!.value, _lngAnim!.value), _zoomAnim!.value);
  }

  void _flyTo(LatLng dest, double destZoom) {
    final cam = _mapController.camera;
    _latAnim = Tween<double>(begin: cam.center.latitude, end: dest.latitude)
        .animate(CurvedAnimation(
            parent: _cameraAnim, curve: Curves.easeInOutCubic));
    _lngAnim = Tween<double>(begin: cam.center.longitude, end: dest.longitude)
        .animate(CurvedAnimation(
            parent: _cameraAnim, curve: Curves.easeInOutCubic));
    _zoomAnim = Tween<double>(begin: cam.zoom, end: destZoom).animate(
        CurvedAnimation(parent: _cameraAnim, curve: Curves.easeInOutCubic));
    _cameraAnim.forward(from: 0);
  }

  void _onMapReady() {
    _mapReady = true;
    if (_isEditing && _selectedPoint != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _flyTo(_selectedPoint!, 15));
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _flyTo(_kgOverview, _kgOverviewZoom));
    }
  }

  // ── Reverse geocoding ─────────────────────────────────────────
  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _geocoding = true);
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?lat=${point.latitude}&lon=${point.longitude}'
          '&format=json&addressdetails=1&accept-language=ru');
      final res = await http
          .get(uri, headers: {'User-Agent': 'autosalon-app/1.0'})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = json['address'] as Map<String, dynamic>? ?? {};
        final road =
            addr['road'] ?? addr['pedestrian'] ?? addr['footway'] ?? '';
        final houseNumber = addr['house_number'] ?? '';
        final suburb = addr['suburb'] ?? addr['neighbourhood'] ?? '';

        // Расширенная цепочка fallback'ов — Nominatim кладёт населённый
        // пункт под разными ключами в зависимости от региона/уровня админ.
        // деления, особенно за пределами крупных городов КР.
        final city = addr['city'] ??
            addr['town'] ??
            addr['village'] ??
            addr['municipality'] ??
            addr['city_district'] ??
            addr['county'] ??
            addr['state_district'] ??
            '';

        final streetPart =
            [road, houseNumber].where((s) => s.isNotEmpty).join(', ');
        var full =
            [streetPart, suburb, city].where((s) => s.isNotEmpty).join(', ');

        // Если структурированный адрес пуст — используем display_name
        // как запасной вариант, чтобы поле адреса не оставалось пустым.
        if (full.isEmpty) {
          final displayName = json['display_name'] as String? ?? '';
          full = displayName.split(',').take(3).join(',').trim();
        }

        setState(() {
          _resolvedCity = city.isNotEmpty
              ? city
              : (suburb.isNotEmpty
                  ? suburb
                  : (_activeCity ?? 'Точка на карте'));
          if (full.isNotEmpty) {
            _addressController.text = full;
            _addressController.selection =
                TextSelection.collapsed(offset: _addressController.text.length);
          }
        });
      } else {
        _showGeocodeError();
      }
    } catch (_) {
      if (mounted) _showGeocodeError();
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  void _showGeocodeError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Не удалось определить адрес. Попробуйте ещё раз.')),
    );
  }

  // ── Current location (с запросом разрешения) ──────────────────
  Future<void> _goToMyLocation() async {
    if (_locating) return;

    // 1. Включена ли геолокация (GPS) на устройстве?
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      final open = await _showPermissionDialog(
        title: 'Геолокация выключена',
        message:
            'Чтобы определить, где вы находитесь, включите геолокацию (GPS) на устройстве.',
        confirmText: 'Открыть настройки',
      );
      if (open == true) await Geolocator.openLocationSettings();
      return;
    }

    // 2. Текущий статус разрешения
    var permission = await Geolocator.checkPermission();

    // Разрешение ещё не выдано — сначала спрашиваем пользователя,
    // затем показываем системный запрос.
    if (permission == LocationPermission.denied) {
      if (!mounted) return;
      final allow = await _showPermissionDialog(
        title: 'Доступ к местоположению',
        message:
            'Разрешите доступ к геолокации, чтобы автоматически найти, где вы находитесь, и отметить точку на карте.',
        confirmText: 'Разрешить',
      );
      if (allow != true) return; // пользователь отказался
      permission = await Geolocator.requestPermission();
    }

    // Запрещено навсегда — ведём в системные настройки приложения.
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      final open = await _showPermissionDialog(
        title: 'Доступ запрещён',
        message:
            'Доступ к геолокации запрещён. Откройте настройки приложения и разрешите его вручную.',
        confirmText: 'Открыть настройки',
      );
      if (open == true) await Geolocator.openAppSettings();
      return;
    }

    // Пользователь отклонил системный запрос
    if (permission == LocationPermission.denied) return;

    // 3. Разрешение есть — ищем и показываем местоположение
    await _fetchAndShowLocation();
  }

  Future<void> _fetchAndShowLocation() async {
    setState(() => _locating = true);
    try {
      // Последняя известная позиция приходит мгновенно — запасной вариант.
      Position? pos = await Geolocator.getLastKnownPosition();

      // Свежие координаты (до 20 сек). Если истёк таймаут, но есть
      // last-known — используем её вместо ошибки.
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium, // быстрее ловит сигнал, чем high
            timeLimit: Duration(seconds: 20),
          ),
        );
      } on TimeoutException {
        if (pos == null) {
          _showLocationError(
              'Не удалось поймать сигнал GPS. Попробуйте на открытом месте.');
          return;
        }
      }

      if (pos == null) {
        _showLocationError('Не удалось определить местоположение.');
        return;
      }

      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _activeCity = null;
        _selectedPoint = point;
        _addressController.text = '';
      });
      _flyTo(point, 16);
      _reverseGeocode(point); // адрес подтянется автоматически
    } catch (e) {
      _showLocationError('Ошибка геолокации: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // Диалог-запрос разрешения (rationale) перед системным запросом.
  Future<bool?> _showPermissionDialog({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.w)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.2.w),
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F4),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on, color: _accent, size: 2.6.h),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.black)),
            ),
          ],
        ),
        content: Text(message,
            style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF6A6A70),
                height: 1.45)),
        actionsPadding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.8.h),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx, false),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
              child: Text('Отмена',
                  style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFF9A9AA0),
                      fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(width: 1.w),
          _PressableScale(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.2.h),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Text(confirmText,
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Place search ──────────────────────────────────────────────
  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(query)}'
          '&format=json&limit=5&accept-language=ru');
      final res = await http
          .get(uri, headers: {'User-Agent': 'autosalon-app/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _searchResults = list.cast<Map<String, dynamic>>();
          _showResults = _searchResults.isNotEmpty;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onSearchResultTapped(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat'] as String? ?? '') ?? 0;
    final lng = double.tryParse(result['lon'] as String? ?? '') ?? 0;
    final point = LatLng(lat, lng);
    final displayName = result['display_name'] as String? ?? '';
    setState(() {
      _activeCity = null;
      _selectedPoint = point;
      _addressController.text = displayName;
      _searchController.text = displayName.split(',').first;
      _showResults = false;
      _searchResults = [];
    });
    _flyTo(point, 15);
    FocusScope.of(context).unfocus();
  }

  void _selectCity(_KgCity city) {
    setState(() {
      _activeCity = city.name;
      _selectedPoint = city.coords;
      _resolvedCity = city.name;
      _addressController.text = '';
    });
    _flyTo(city.coords, city.zoom);
    _reverseGeocode(city.coords);
  }

  void _selectCustomPoint(LatLng point) {
    setState(() {
      _activeCity = null;
      _selectedPoint = point;
      _addressController.text = '';
    });
    _reverseGeocode(point);
  }

  void _goToMap() => setState(() => _step = _Step.map);
  void _backToIntro() => setState(() => _step = _Step.intro);

  // ── Location photos ───────────────────────────────────────────
  Future<void> _pickLocPhoto(ImageSource source) async {
    if (_locPhotos.length >= _maxLocPhotos) return;
    try {
      final x =
          await _picker.pickImage(source: source, imageQuality: 80);
      if (x != null) setState(() => _locPhotos.add(x));
    } catch (_) {}
  }

  void _removeLocPhoto(int i) => setState(() => _locPhotos.removeAt(i));

  void _showLocPhotoSheet() {
    if (_locPhotos.length >= _maxLocPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Максимум 2 фото для локации')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoSourceSheet(
        title: 'Фото локации',
        onCamera: () {
          Navigator.pop(context);
          _pickLocPhoto(ImageSource.camera);
        },
        onGallery: () {
          Navigator.pop(context);
          _pickLocPhoto(ImageSource.gallery);
        },
      ),
    );
  }

  void _save() {
    if (_selectedPoint == null) return;
    final city = _resolvedCity.isNotEmpty
        ? _resolvedCity
        : (_activeCity ?? 'Точка на карте');
    final typed = _addressController.text.trim();
    final result = (
      city,
      typed.isEmpty ? city : typed,
      _selectedPoint!.latitude,
      _selectedPoint!.longitude,
      List<XFile>.from(_locPhotos),
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F4),
      body: SafeArea(
        child: _step == _Step.intro ? _introView() : _mapView(),
      ),
    );
  }

  // ── Step 1: empty state ──────────────────────────────────────
  Widget _fade(int order, Widget child) {
    final start = (order * 0.08).clamp(0.0, 0.7);
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
            offset: Offset(0, (1 - curved.value) * 2.h), child: c),
      ),
      child: child,
    );
  }

  Widget _introView() {
    int order = 0;
    Widget a(Widget c) => _fade(order++, c);
    return Column(
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
                  child:
                      Icon(Icons.arrow_back, color: Colors.black, size: 3.2.h),
                ),
              ),
              Expanded(
                child: a(Text(
                  'Локация автосалона',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: -0.4,
                  ),
                )),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  a(Container(
                    width: 24.w,
                    height: 24.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFEAEAEE), width: 1.4),
                    ),
                    child: Icon(Icons.add_location_alt_outlined,
                        color: _accent, size: 9.w),
                  )),
                  SizedBox(height: 3.h),
                  a(Text(
                    'Локация пока не добавлена',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.black),
                  )),
                  SizedBox(height: 1.h),
                  a(Text(
                    'Отметьте на карте, где находится ваш автосалон, чтобы клиенты могли вас найти',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5.sp,
                        color: const Color(0xFF9A9AA0),
                        height: 1.4),
                  )),
                  SizedBox(height: 3.5.h),
                  a(_PressableScale(
                    onTap: _goToMap,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 2.h),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined,
                              color: Colors.white, size: 2.2.h),
                          SizedBox(width: 2.w),
                          Text('Добавить на карте',
                              style: TextStyle(
                                  fontSize: 14.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.2)),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: map ──────────────────────────────────────────────
  Widget _mapView() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _isEditing
                ? LatLng(widget.initialLat, widget.initialLng)
                : const LatLng(10.0, 20.0),
            initialZoom: _isEditing ? 15.0 : 1.8,
            onMapReady: _onMapReady,
            onTap: (_, point) => _selectCustomPoint(point),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.newapp.autosalon',
            ),
            if (_selectedPoint != null)
              MarkerLayer(markers: [
                Marker(
                  point: _selectedPoint!,
                  width: 10.w,
                  height: 10.w,
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.location_on, color: _accent, size: 9.w),
                ),
              ]),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors')
              ],
            ),
          ],
        ),

        // Back button
        Positioned(
          top: 1.5.h,
          left: 4.w,
          child: SafeArea(
              child: _circleButton(
                  Icons.arrow_back,
                  _isEditing
                      ? () => Navigator.maybePop(context)
                      : _backToIntro)),
        ),

        // Search + chips
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search bar
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 1.h, 4.w, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3.w),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchPlaces,
                      onSubmitted: _searchPlaces,
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Поиск места, улицы...',
                        hintStyle: TextStyle(
                            fontSize: 12.5.sp,
                            color: const Color(0xFFB4B4BA)),
                        prefixIcon: _searching
                            ? Padding(
                                padding: EdgeInsets.all(2.5.w),
                                child: SizedBox(
                                  width: 2.h,
                                  height: 2.h,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _accent),
                                ),
                              )
                            : Icon(Icons.search,
                                color: const Color(0xFF8A8A90), size: 2.4.h),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                    _showResults = false;
                                  });
                                },
                                child: Icon(Icons.close,
                                    color: const Color(0xFF8A8A90), size: 2.h),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 1.5.h),
                      ),
                    ),
                  ),
                ),

                // Autocomplete results
                if (_showResults)
                  Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 0.5.h, 4.w, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3.w),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _searchResults.take(5).map((r) {
                          final parts =
                              (r['display_name'] as String? ?? '').split(',');
                          return InkWell(
                            onTap: () => _onSearchResultTapped(r),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4.w, vertical: 1.4.h),
                              child: Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 2.h,
                                      color: const Color(0xFF8A8A90)),
                                  SizedBox(width: 2.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(parts.first.trim(),
                                            style: TextStyle(
                                                fontSize: 12.5.sp,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black)),
                                        if (parts.length > 1)
                                          Text(
                                              parts
                                                  .sublist(1)
                                                  .take(2)
                                                  .join(',')
                                                  .trim(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 10.5.sp,
                                                  color: const Color(
                                                      0xFF9A9AA0))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                // City chips
                Padding(
                  padding: EdgeInsets.only(top: 1.h, bottom: 0.5.h),
                  child: SizedBox(
                    height: 5.5.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      itemCount: _kgCities.length,
                      separatorBuilder: (_, __) => SizedBox(width: 2.w),
                      itemBuilder: (_, i) => _cityChip(_kgCities[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Кнопка "моё местоположение" + карточка подтверждения
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: 4.w, bottom: 1.2.h),
                  child: _locateButton(),
                ),
                if (_selectedPoint != null) _confirmCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(2.2.w),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Icon(icon, color: Colors.black, size: 2.4.h),
      ),
    );
  }

  // "My location" button — shows a spinner while resolving GPS.
  Widget _locateButton() {
    return _PressableScale(
      onTap: _goToMyLocation,
      child: Container(
        padding: EdgeInsets.all(2.6.w),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: _locating
            ? SizedBox(
                width: 2.4.h,
                height: 2.4.h,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _accent),
              )
            : Icon(Icons.my_location, color: _accent, size: 2.4.h),
      ),
    );
  }

  Widget _cityChip(_KgCity city) {
    final active = _activeCity == city.name;
    return _PressableScale(
      onTap: () => _selectCity(city),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _accent : Colors.white,
          borderRadius: BorderRadius.circular(10.w),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Text(
          city.name,
          style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  // ── Confirm card (also used for editing) ─────────────────────
  Widget _confirmCard() {
    final displayCity = _resolvedCity.isNotEmpty
        ? _resolvedCity
        : (_activeCity ?? 'Точка на карте');
    final canAdd = _locPhotos.length < _maxLocPhotos;

    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // City / loading row
          Row(
            children: [
              Icon(Icons.place, color: _accent, size: 2.2.h),
              SizedBox(width: 2.w),
              Expanded(
                child: _geocoding
                    ? Row(
                        children: [
                          SizedBox(
                            width: 1.8.h,
                            height: 1.8.h,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _accent),
                          ),
                          SizedBox(width: 2.w),
                          Text('Определяем адрес...',
                              style: TextStyle(
                                  fontSize: 13.sp,
                                  color: const Color(0xFF9A9AA0))),
                        ],
                      )
                    : Text(
                        displayCity,
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.black),
                      ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),

          // Address field
          TextField(
            controller: _addressController,
            cursorColor: _accent,
            style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: Colors.black),
            decoration: InputDecoration(
              hintText: 'Уточните адрес (улица, дом, ТЦ)',
              hintStyle: TextStyle(
                  fontSize: 12.5.sp, color: const Color(0xFFB4B4BA)),
              filled: true,
              fillColor: const Color(0xFFF8F8FA),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.6.h),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3.5.w),
                borderSide:
                    const BorderSide(color: Color(0xFFEAEAEE), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3.5.w),
                borderSide: BorderSide(color: _accent, width: 1.4),
              ),
            ),
          ),
          SizedBox(height: 1.8.h),

          // ── Location photos row (max 2) ───────────────────────
          Row(
            children: [
              Text('Фото локации',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.black)),
              SizedBox(width: 2.w),
              Text('${_locPhotos.length}/2',
                  style: TextStyle(
                      fontSize: 12.sp, color: const Color(0xFFB4B4BA))),
            ],
          ),
          SizedBox(height: 1.h),
          Row(
            children: [
              // Existing photos
              for (int i = 0; i < _locPhotos.length; i++) ...[
                _locPhotoThumb(i),
                SizedBox(width: 2.w),
              ],
              // Add tile — only if under limit
              if (canAdd)
                _PressableScale(
                  onTap: _showLocPhotoSheet,
                  child: Container(
                    width: 14.w,
                    height: 14.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F4),
                      borderRadius: BorderRadius.circular(3.w),
                      border: Border.all(
                          color: const Color(0xFFE2E2E6), width: 1.4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            color: _accent, size: 2.2.h),
                        SizedBox(height: 0.3.h),
                        Text('Фото',
                            style: TextStyle(
                                fontSize: 8.5.sp,
                                color: const Color(0xFF8A8A90),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),

          // Save button
          _PressableScale(
            onTap: _save,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 1.8.h),
              decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(3.5.w)),
              alignment: Alignment.center,
              child: Text(
                  _isEditing ? 'Сохранить изменения' : 'Сохранить локацию',
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locPhotoThumb(int i) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3.w),
          child: Image.file(File(_locPhotos[i].path),
              width: 14.w, height: 14.w, fit: BoxFit.cover),
        ),
        Positioned(
          top: 0.5.w,
          right: 0.5.w,
          child: GestureDetector(
            onTap: () => _removeLocPhoto(i),
            child: Container(
              padding: EdgeInsets.all(0.5.w),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  shape: BoxShape.circle),
              child: Icon(Icons.close, color: Colors.white, size: 1.4.h),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Photo source sheet ────────────────────────────────────────────
class _PhotoSourceSheet extends StatelessWidget {
  final String title;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _PhotoSourceSheet({
    required this.title,
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
              _option(context, Icons.photo_camera_outlined, 'Сделать фото',
                  onCamera),
              SizedBox(height: 1.4.h),
              _option(context, Icons.photo_library_outlined,
                  'Выбрать из галереи', onGallery),
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

  Widget _option(
      BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
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

// ── Press-to-scale wrapper ───────────────────────────────────────
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  const _PressableScale(
      {required this.child, required this.onTap, this.scale = 0.97});

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