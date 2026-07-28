import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

/// Standalone screen for editing the autosalon's public profile — name,
/// tagline, logo, and "years on the market".
///
/// Opened from the publish page's salon card ("Редактировать"). On save,
/// the edited values are returned to the caller via `Navigator.pop` as a
/// record: `(name, tagline, years, logo)`. Returning `null` (back button)
/// means the caller should keep whatever it already had.
class ProfileEdit extends StatefulWidget {
  final String initialName;
  final String initialTagline;
  final String initialYears;
  final XFile? initialLogo;

  const ProfileEdit({
    Key? key,
    this.initialName = '',
    this.initialTagline = '',
    this.initialYears = '',
    this.initialLogo,
  }) : super(key: key);

  @override
  State<ProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<ProfileEdit> {
  static const _accent = Color(0xFF111111);

  late final _nameController = TextEditingController(text: widget.initialName);
  late final _taglineController =
      TextEditingController(text: widget.initialTagline);
  late final _yearsController = TextEditingController(text: widget.initialYears);

  final ImagePicker _picker = ImagePicker();
  XFile? _logo;

  @override
  void initState() {
    super.initState();
    _logo = widget.initialLogo;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo(ImageSource source) async {
    try {
      final x = await _picker.pickImage(source: source, imageQuality: 80);
      if (x != null) setState(() => _logo = x);
    } catch (_) {}
  }

  void _showLogoSheet() => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _SourceSheet(
          title: 'Логотип автосалона',
          cameraLabel: 'Сделать фото',
          galleryLabel: 'Выбрать из галереи',
          onCamera: () {
            Navigator.pop(context);
            _pickLogo(ImageSource.camera);
          },
          onGallery: () {
            Navigator.pop(context);
            _pickLogo(ImageSource.gallery);
          },
        ),
      );

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название автосалона')),
      );
      return;
    }
    Navigator.pop(
      context,
      (
        name,
        _taglineController.text.trim(),
        _yearsController.text.trim(),
        _logo,
      ),
    );
  }

  InputDecoration _decoration(String hint) {
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
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      enabledBorder: b(const Color(0xFFEAEAEE)),
      focusedBorder: b(_accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F4),
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
                      child: Icon(Icons.arrow_back,
                          color: Colors.black, size: 3.2.h),
                    ),
                  ),
                  Expanded(
                    child: Text('Редактировать профиль',
                        style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: -0.5)),
                  ),
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
                    Center(child: _logoPicker()),
                    SizedBox(height: 3.5.h),
                    _label('Название автосалона'),
                    SizedBox(height: 1.2.h),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black),
                      decoration: _decoration('Напр. Dream Motors'),
                    ),
                    SizedBox(height: 2.5.h),
                    _label('Слоган / описание'),
                    SizedBox(height: 1.2.h),
                    TextField(
                      controller: _taglineController,
                      maxLines: 3,
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          height: 1.4),
                      decoration:
                          _decoration('Чем выделяется ваш автосалон...'),
                    ),
                    SizedBox(height: 2.5.h),
                    _label('Лет на рынке'),
                    SizedBox(height: 1.2.h),
                    TextField(
                      controller: _yearsController,
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black),
                      decoration: _decoration('Напр. 3 года'),
                    ),
                    SizedBox(height: 4.h),
                    _saveButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.black));

  Widget _logoPicker() {
    return GestureDetector(
      onTap: _showLogoSheet,
      child: Stack(
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F1EC),
              borderRadius: BorderRadius.circular(5.w),
              border: Border.all(color: const Color(0xFFE7DFD6), width: 1.2),
            ),
            child: _logo == null
                ? Icon(Icons.directions_car_filled,
                    color: const Color(0xFFC0392B), size: 6.h)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(5.w),
                    child: Image.file(File(_logo!.path),
                        width: 24.w, height: 24.w, fit: BoxFit.cover),
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(1.6.w),
              decoration: const BoxDecoration(
                  color: Color(0xFF111111), shape: BoxShape.circle),
              child: Icon(Icons.edit, color: Colors.white, size: 1.8.h),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return GestureDetector(
      onTap: _save,
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
        child: Text('Сохранить изменения',
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2)),
      ),
    );
  }
}

// ── Bottom sheet: camera / gallery (self-contained copy so this file
// doesn't depend on the publish page's private widgets) ──────────────
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