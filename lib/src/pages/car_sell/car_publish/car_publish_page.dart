import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_app/src/pages/autoslon/permission/publish_permission.dart';
import 'package:new_app/src/pages/home/models/car.dart';
import 'package:new_app/src/pages/home/providers/cars_provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

/// Dedicated publish form for the car-sell flow. [CarSellPage] only handles
/// the access-request flow now; once permission is granted it pushes this
/// page, which owns the actual form (including photos/video), the publish
/// confirmation, and consuming the one-time permission. On success it pops
/// with the new [Car].
class CarPublishPage extends StatefulWidget {
  const CarPublishPage({Key? key}) : super(key: key);

  @override
  State<CarPublishPage> createState() => _CarPublishPageState();
}

class _CarPublishPageState extends State<CarPublishPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ── Text controllers ──────────────────────────────────────────
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  final _kmController = TextEditingController();
  final _priceController = TextEditingController();
  final _engineController = TextEditingController();
  final _colorController = TextEditingController();
  final _locationController = TextEditingController();
  final _ownersController = TextEditingController();
  final _descController = TextEditingController();
  final _changesController = TextEditingController();
  final _phoneController = TextEditingController();

  // ── Dropdown selections ───────────────────────────────────────
  String? _transmission;
  String? _fuelType;
  String? _bodyType;
  String? _driveType;
  String? _condition;

  // ── Price / contact options ────────────────────────────────────
  bool _priceNegotiable = false;
  bool _contactWhatsapp = false;
  bool _contactTelegram = false;

  static const _transmissions = ['Механика', 'Автомат', 'Робот', 'Вариатор'];
  static const _fuelTypes = ['Бензин', 'Дизель', 'Газ', 'Электро', 'Гибрид'];
  static const _bodyTypes = [
    'Седан', 'Хэтчбек', 'Внедорожник', 'Универсал', 'Купе', 'Минивэн'
  ];
  static const _driveTypes = ['Передний', 'Задний', 'Полный'];
  static const _conditions = [
    'Новый', 'Б/у', 'После аварии', 'Требует ремонта'
  ];

  // ── Photos / video ─────────────────────────────────────────────
  static const _maxPhotos = 4;
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];
  XFile? _video;

  // Live preview for the picked video (first frame + play/pause + duration).
  // Rebuilt whenever a new video is chosen and torn down on remove/replace.
  VideoPlayerController? _videoPreviewController;
  Duration? _videoDuration;
  bool _videoPreviewReady = false;

  // True while photos/video are being uploaded to Firebase Storage and the
  // Firestore document is being written — blocks the submit button.
  bool _isUploading = false;

  // Live text shown under the spinner while uploading, e.g. "Фото 2/4…" —
  // gives the user real feedback instead of a silent spinner, and doubles
  // as a debug signal for exactly where things are.
  String _uploadStatus = '';

  // Accent color — publish actions are black, matching the autoslon flow.
  static const _accent = Color(0xFF111111);

  // ── Entrance animation (same staggered approach as autoslon) ──
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
    _videoPreviewController?.dispose();
    _nameController.dispose();
    _yearController.dispose();
    _kmController.dispose();
    _priceController.dispose();
    _engineController.dispose();
    _colorController.dispose();
    _locationController.dispose();
    _ownersController.dispose();
    _descController.dispose();
    _changesController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Staggered entrance animation helper, identical pattern to AutoslonPublishPage.
  Widget _anim(int order, Widget child) {
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
          offset: Offset(0, (1 - curved.value) * 2.5.h),
          child: c,
        ),
      ),
      child: child,
    );
  }

  // ── Media pickers (same UX as the autoslon publish page) ──────
  void _maxReached() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Максимум 4 фото')),
      );

  Future<void> _addPhotoFromCamera() async {
    if (_photos.length >= _maxPhotos) return _maxReached();
    try {
      final x =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
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

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final x = await _picker.pickVideo(
          source: source, maxDuration: const Duration(minutes: 2));
      if (x != null) await _initVideoPreview(x);
    } catch (_) {}
  }

  // Initializes a preview controller for the freshly picked video so the
  // seller can see exactly what buyers will see in the feed.
  Future<void> _initVideoPreview(XFile file) async {
    await _disposeVideoPreview();
    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
      controller.setLooping(true);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _video = file;
        _videoPreviewController = controller;
        _videoDuration = controller.value.duration;
        _videoPreviewReady = true;
      });
    } catch (_) {
      controller.dispose();
      // Still keep the file even if the preview couldn't initialize.
      if (mounted) {
        setState(() {
          _video = file;
          _videoPreviewReady = false;
        });
      }
    }
  }

  Future<void> _disposeVideoPreview() async {
    final c = _videoPreviewController;
    _videoPreviewController = null;
    _videoPreviewReady = false;
    _videoDuration = null;
    await c?.pause();
    await c?.dispose();
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _removePhoto(int i) => setState(() => _photos.removeAt(i));

  void _removeVideo() {
    _disposeVideoPreview();
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

  // Uploads one file with a hard timeout and live progress logging, so a
  // stalled/denied upload fails loudly after [timeout] instead of spinning
  // forever. Returns the download URL.
  Future<String> _uploadWithTimeout({
    required Reference ref,
    required File file,
    required String contentType,
    required String label,
    required Duration timeout,
  }) async {
    final sizeBytes = await file.length();
    debugPrint('▶ $label: starting upload, size=$sizeBytes bytes, path=${ref.fullPath}');

    final task = ref.putFile(file, SettableMetadata(contentType: contentType));

    final sub = task.snapshotEvents.listen((s) {
      final pct = s.totalBytes > 0
          ? (s.bytesTransferred / s.totalBytes * 100).toStringAsFixed(0)
          : '?';
      debugPrint('  $label: ${s.state.name} $pct% (${s.bytesTransferred}/${s.totalBytes})');
      if (mounted) {
        setState(() => _uploadStatus = '$label: $pct%');
      }
    });

    try {
      await task.timeout(
        timeout,
        onTimeout: () {
          task.cancel();
          throw Exception(
              '$label: загрузка не завершилась за ${timeout.inMinutes} мин. '
              'Проверьте интернет-соединение и попробуйте снова.');
        },
      );
    } finally {
      await sub.cancel();
    }

    debugPrint('✔ $label: upload complete');
    return ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (_isUploading) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }
    if (_driveType == null || _condition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одно фото')),
      );
      return;
    }
    if (!_contactWhatsapp && !_contactTelegram) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Выберите хотя бы один способ связи: WhatsApp или Telegram')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    // Capture providers before any await (avoids using context across gaps).
    final notifier = context.read<CarSellPermissionNotifier>();
    final carsProvider = context.read<CarsProvider>();

    // The publish button does not publish immediately: confirm first.
    final confirmed = await showPublishConfirmDialog(context);
    if (!confirmed || !mounted) return;

    final carId = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Подготовка…';
    });

    try {
      final storage = FirebaseStorage.instance;
      debugPrint('▶ publish start, bucket=${storage.bucket}, carId=$carId');

      // ── Загрузка фото в Storage ─────────────────────────────
      final photoUrls = <String>[];
      for (int i = 0; i < _photos.length; i++) {
        if (mounted) {
          setState(() => _uploadStatus = 'Фото ${i + 1}/${_photos.length}…');
        }
        final file = File(_photos[i].path);
        final ref = storage.ref('cars/${user.uid}/$carId/photo_$i.jpg');
        final url = await _uploadWithTimeout(
          ref: ref,
          file: file,
          contentType: 'image/jpeg',
          label: 'Фото ${i + 1}',
          timeout: const Duration(minutes: 2),
        );
        photoUrls.add(url);
      }

      // ── Загрузка видео в Storage (если есть) ─────────────────
      String? videoUrl;
      if (_video != null) {
        if (mounted) {
          setState(() => _uploadStatus = 'Загрузка видео…');
        }
        final file = File(_video!.path);
        final ref = storage.ref('cars/${user.uid}/$carId/video.mp4');
        videoUrl = await _uploadWithTimeout(
          ref: ref,
          file: file,
          contentType: 'video/mp4',
          label: 'Видео',
          // Video is bigger — give it more time before we give up.
          timeout: const Duration(minutes: 6),
        );
      }

      if (mounted) {
        setState(() => _uploadStatus = 'Публикация объявления…');
      }

      final car = Car(
        id: carId,
        ownerId: user.uid,
        name: _nameController.text.trim(),
        year: _yearController.text.trim(),
        km: _kmController.text.trim(),
        price: _priceController.text.trim(),
        transmission: _transmission!,
        fuelType: _fuelType!,
        engineCapacity: _engineController.text.trim(),
        bodyType: _bodyType!,
        color: _colorController.text.trim(),
        location: _locationController.text.trim(),
        ownersCount: _ownersController.text.trim(),
        description: _descController.text.trim(),
        driveType: _driveType!,
        condition: _condition!,
        photoPaths: photoUrls, // Storage-URL, не локальные пути
        videoPath: videoUrl,   // Storage-URL
        priceNegotiable: _priceNegotiable,
        changesDescription: _changesController.text.trim(),
        phone: _phoneController.text.trim(),
        contactWhatsapp: _contactWhatsapp,
        contactTelegram: _contactTelegram,
      );

      // Пишет документ в Firestore; список на Home/Video обновится сам
      // через живую подписку CarsProvider. Guarded by its own timeout too —
      // a permission-denied write can otherwise hang the UI just like a
      // stalled Storage upload would.
      debugPrint('▶ writing Firestore doc…');
      await carsProvider.publishCar(car).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception(
            'Не удалось сохранить объявление (тайм-аут). Попробуйте снова.'),
      );
      debugPrint('✔ Firestore doc written');

      // Consume the one-time permission, then return the new car. After this
      // the user must request permission again for the next listing.
      await notifier.consume();
      if (!mounted) return;

      Navigator.pop(context, car);
    } catch (e) {
      debugPrint('✖ publish error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка публикации: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int order = 0;
    Widget a(Widget c) => _anim(order++, c);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header — back arrow sits inline to the left of the title,
            // right at the very top, like a normal app bar.
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
                              color: _accent, size: 3.2.h),
                        ),
                      ),
                      Expanded(
                        child: a(Text(
                          'Продажа авто',
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w800,
                            color: _accent,
                            letterSpacing: -0.5,
                          ),
                        )),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  a(Text(
                    'Укажите характеристики вашего автомобиля.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF9A9AA0),
                    ),
                  )),
                ],
              ),
            ),

            // Scrollable form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(5.w, 3.h, 5.w, 2.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      a(_sectionTitle('Фотографии', '${_photos.length}/$_maxPhotos')),
                      SizedBox(height: 1.5.h),
                      a(_photoWrap()),
                      SizedBox(height: 3.h),
                      a(_sectionTitle('Видео', _video == null ? '' : '1')),
                      SizedBox(height: 1.5.h),
                      a(_videoArea()),
                      SizedBox(height: 3.h),
                      a(_section('Основное')),
                      a(_textField(
                        label: 'Марка и модель',
                        controller: _nameController,
                        hint: 'Toyota Camry',
                        icon: Icons.directions_car_outlined,
                      )),
                      a(_textField(
                        label: 'Цена, \$',
                        controller: _priceController,
                        hint: '15 000',
                        icon: Icons.attach_money,
                        keyboardType: TextInputType.number,
                      )),
                      a(_negotiableSwitch()),
                      a(_section('Характеристики')),
                      a(Row(
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
                      )),
                      a(_dropdownField(
                        label: 'Коробка передач',
                        value: _transmission,
                        items: _transmissions,
                        icon: Icons.settings_outlined,
                        onChanged: (v) => setState(() => _transmission = v),
                      )),
                      a(_dropdownField(
                        label: 'Тип топлива',
                        value: _fuelType,
                        items: _fuelTypes,
                        icon: Icons.local_gas_station_outlined,
                        onChanged: (v) => setState(() => _fuelType = v),
                      )),
                      a(_dropdownField(
                        label: 'Тип кузова',
                        value: _bodyType,
                        items: _bodyTypes,
                        icon: Icons.airport_shuttle_outlined,
                        onChanged: (v) => setState(() => _bodyType = v),
                      )),
                      a(_dropdownField(
                        label: 'Привод',
                        value: _driveType,
                        items: _driveTypes,
                        icon: Icons.all_inclusive_outlined,
                        onChanged: (v) => setState(() => _driveType = v),
                      )),
                      a(Row(
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
                      )),
                      a(_section('Состояние и история')),
                      a(_dropdownField(
                        label: 'Состояние',
                        value: _condition,
                        items: _conditions,
                        icon: Icons.health_and_safety_outlined,
                        onChanged: (v) => setState(() => _condition = v),
                      )),
                      a(_textField(
                        label: 'Количество владельцев',
                        controller: _ownersController,
                        hint: '1',
                        icon: Icons.groups_outlined,
                        keyboardType: TextInputType.number,
                      )),
                      a(_descField()),
                      a(_changesField()),
                      a(_section('Расположение')),
                      a(_textField(
                        label: 'Город',
                        controller: _locationController,
                        hint: 'Бишкек',
                        icon: Icons.location_on_outlined,
                      )),
                      a(_section('Контакты')),
                      a(_textField(
                        label: 'Номер телефона',
                        controller: _phoneController,
                        hint: '+996 700 000 000',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      )),
                      a(_contactMethodPicker()),
                      SizedBox(height: 2.h),
                      a(_submitButton()),
                      SizedBox(height: 2.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Photos / video widgets ─────────────────────────────────────

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
                border: Border.all(color: const Color(0xFFE2E2E6), width: 1.4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: _accent, size: 3.2.h),
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

    final ready = _videoPreviewReady && _videoPreviewController != null;
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
            aspectRatio:
                ready ? _videoPreviewController!.value.aspectRatio : 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3.w),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (ready)
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
                  if (ready)
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
                  if (_videoDuration != null)
                    Positioned(
                      right: 2.w,
                      bottom: 1.h,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 2.w, vertical: 0.3.h),
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(2.w)),
                        child: Text(_fmtDuration(_videoDuration!),
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600)),
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
                        Icon(Icons.autorenew_rounded, size: 2.h, color: _accent),
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

  // ── Price negotiable toggle ─────────────────────────────────────

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

  // ── Changes / improvements field ────────────────────────────────

  Widget _changesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Что было изменено / отремонтировано (необязательно)'),
        TextFormField(
          controller: _changesController,
          maxLines: 4,
          maxLength: 500,
          cursorColor: _accent,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: _accent,
            height: 1.4,
          ),
          decoration: _decoration(
              hint: 'Например: заменена подвеска, новые шины, покраска крыла...'),
        ),
        SizedBox(height: 2.h),
      ],
    );
  }

  // ── Contact method picker (WhatsApp / Telegram) ─────────────────

  Widget _contactMethodPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Как с вами можно связаться'),
        Row(
          children: [
            Expanded(
              child: _contactChip(
                label: 'WhatsApp',
                icon: Icons.chat_outlined,
                selected: _contactWhatsapp,
                onTap: () =>
                    setState(() => _contactWhatsapp = !_contactWhatsapp),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _contactChip(
                label: 'Telegram',
                icon: Icons.send_outlined,
                selected: _contactTelegram,
                onTap: () =>
                    setState(() => _contactTelegram = !_contactTelegram),
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
      ],
    );
  }

  Widget _contactChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: 1.6.h),
        decoration: BoxDecoration(
          color: selected ? _accent : const Color(0xFFF2F2F4),
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(
            color: selected ? _accent : const Color(0xFFEAEAEE),
            width: 1.4,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? Colors.white : const Color(0xFF8A8A90),
                size: 2.2.h),
            SizedBox(width: 2.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────

  Widget _section(String title) => Padding(
        padding: EdgeInsets.only(bottom: 1.6.h, top: 0.5.h),
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

  InputDecoration _decoration({String? hint, IconData? icon}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(4.w),
          borderSide: BorderSide(color: c, width: 1.4),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13.sp,
        color: const Color(0xFFB4B4BA),
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: icon != null
          ? Icon(icon, color: const Color(0xFF8A8A90), size: 2.4.h)
          : null,
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      enabledBorder: border(const Color(0xFFEAEAEE)),
      focusedBorder: border(_accent),
      errorBorder: border(const Color(0xFF555555)),
      focusedErrorBorder: border(const Color(0xFF555555)),
      errorStyle: TextStyle(fontSize: 10.sp, color: const Color(0xFF555555)),
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
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          cursorColor: _accent,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Заполните поле' : null,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: _accent,
          ),
          decoration: _decoration(hint: hint, icon: icon),
        ),
        SizedBox(height: 2.h),
      ],
    );
  }

  Widget _descField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Описание'),
        TextFormField(
          controller: _descController,
          maxLines: 5,
          maxLength: 1000,
          cursorColor: _accent,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Заполните поле' : null,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: _accent,
            height: 1.4,
          ),
          decoration: _decoration(
              hint: 'Расскажите о состоянии, истории обслуживания, комплектации...'),
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
          validator: (v) => v == null ? 'Выберите значение' : null,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: _accent,
          ),
          hint: Text(
            'Выберите',
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFFB4B4BA),
              fontWeight: FontWeight.w400,
            ),
          ),
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

  Widget _submitButton() {
    return _AnimatedPressableButton(
      onTap: _isUploading ? () {} : _submit,
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
        child: _isUploading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 2.2.h,
                    height: 2.2.h,
                    child: const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                  if (_uploadStatus.isNotEmpty) ...[
                    SizedBox(width: 2.5.w),
                    Text(
                      _uploadStatus,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              )
            : Text(
                'Опубликовать объявление',
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
}

// ── Bottom sheet: camera / gallery (same as autoslon publish page) ──────
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

// ── Press-to-scale wrapper (for photo/video tiles) ───────────────
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

// ── Animated Pressable Button (submit) ────────────────────────
class _AnimatedPressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  const _AnimatedPressableButton({
    required this.child,
    required this.onTap,
    this.scale = 0.97,
  });

  @override
  State<_AnimatedPressableButton> createState() =>
      _AnimatedPressableButtonState();
}

class _AnimatedPressableButtonState extends State<_AnimatedPressableButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pressAnimation = Tween<double>(begin: 1, end: widget.scale).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _pressAnimation,
        child: widget.child,
      ),
    );
  }
}