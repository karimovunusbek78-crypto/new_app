import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_app/src/pages/autoslon/permission/publish_permission.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

/// Dedicated publish form for the autosalon flow. This used to be handled
/// by [CarPublishPage] (car_sell/car_publish/car_publish_page.dart) via a
/// `publishType` parameter, but that page is now reserved for the car-sell
/// flow only. This page is its own separate class so the two flows can
/// evolve independently.
class AutoslonPublishPage extends StatefulWidget {
  const AutoslonPublishPage({Key? key}) : super(key: key);

  @override
  State<AutoslonPublishPage> createState() => _AutoslonPublishPageState();
}

class _AutoslonPublishPageState extends State<AutoslonPublishPage>
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFF111111);
  static const _maxPhotos = 10;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];
  XFile? _video;

  final _descController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _bargain = false;

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

  // ── Media pickers ─────────────────────────────────────────────
  void _maxReached() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Максимум 10 фото')),
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

  // The publish button does not publish immediately. It first asks the user to
  // confirm, and only then consumes the one-time permission and finishes.
  Future<void> _publish() async {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одно фото')),
      );
      return;
    }

    // Confirmation dialog: "are you sure everything is filled in?"
    final confirmed = await showPublishConfirmDialog(context);
    if (!confirmed || !mounted) return;

    // TODO: upload _photos / _video (e.g. to Cloudinary or Supabase),
    // then save the listing + media URLs to Firestore.

    // Consume the one-time autosalon permission so the user must request it
    // again for the next listing.
    try {
      await PublishPermissions.consume(PublishType.autoslon);
    } catch (_) {}
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Объявление опубликовано 🎉')),
    );
    Navigator.pop(context);
  }

  // ── Entrance animation helper ─────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    int order = 0;
    Widget a(Widget c) => _anim(order++, c);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F4),
      body: SafeArea(
        child: Column(
          children: [
            // Header — back arrow sits inline to the left of the title,
            // like a normal app bar, with the subtitle below.
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
                    'Добавьте фото, видео и описание автосалона.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF9A9AA0),
                    ),
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
                    a(_sectionTitle('Фотографии', '${_photos.length}/$_maxPhotos')),
                    SizedBox(height: 1.5.h),
                    a(_photoWrap()),
                    SizedBox(height: 3.h),
                    a(_sectionTitle('Видео', _video == null ? '' : '1')),
                    SizedBox(height: 1.5.h),
                    a(_videoArea()),
                    SizedBox(height: 3.h),
                    a(_sectionTitle('Описание', '')),
                    SizedBox(height: 1.5.h),
                    a(_descField()),
                    SizedBox(height: 3.h),
                    a(_sectionTitle('Контакты', '')),
                    SizedBox(height: 1.5.h),
                    a(_phoneField()),
                    SizedBox(height: 1.2.h),
                    a(_bargainSwitch()),
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

  // ── Pieces ────────────────────────────────────────────────────
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

  Widget _photoWrap() {
    final tile = 26.w;
    return Wrap(
      spacing: 3.w,
      runSpacing: 3.w,
      children: [
        // Add tile
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
        // Thumbnails
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
                      color: Colors.black,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 0.4.h),
              Text('Снять на камеру или выбрать из галереи',
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
      child: Row(
        children: [
          Container(
            width: 14.w,
            height: 14.w,
            decoration: BoxDecoration(
                color: _accent, borderRadius: BorderRadius.circular(3.w)),
            child:
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 4.h),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Видео добавлено',
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black)),
                SizedBox(height: 0.4.h),
                Text(_video!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.sp, color: const Color(0xFF9A9AA0))),
              ],
            ),
          ),
          GestureDetector(
            onTap: _removeVideo,
            child: Icon(Icons.delete_outline,
                color: const Color(0xFF8A8A90), size: 2.6.h),
          ),
        ],
      ),
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
          'Расскажите о состоянии, истории обслуживания, комплектации...'),
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

  Widget _bargainSwitch() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFEAEAEE), width: 1.4),
      ),
      child: Row(
        children: [
          Icon(Icons.handshake_outlined,
              color: const Color(0xFF8A8A90), size: 2.6.h),
          SizedBox(width: 3.w),
          Expanded(
            child: Text('Торг уместен',
                style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
          ),
          Switch(
            value: _bargain,
            onChanged: (v) => setState(() => _bargain = v),
            activeColor: Colors.white,
            activeTrackColor: _accent,
          ),
        ],
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

// ── Bottom sheet: camera / gallery ───────────────────────────────
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

// ── Press-to-scale wrapper ───────────────────────────────────────
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