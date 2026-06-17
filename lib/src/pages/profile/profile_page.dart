import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _telegramController;

  final ImagePicker _picker = ImagePicker();
  File? _avatarFile;

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _phoneController = TextEditingController();
    _telegramController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10.w,
                  height: 0.5.h,
                  margin: EdgeInsets.only(bottom: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: Colors.black),
                  title: Text('Сделать фото',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _getImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_outlined, color: Colors.black),
                  title: Text('Выбрать из галереи',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _getImage(ImageSource.gallery);
                  },
                ),
                if (_avatarFile != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Удалить фото',
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _avatarFile = null);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (picked != null) {
        setState(() => _avatarFile = File(picked.path));
        // TODO: upload _avatarFile to Firebase Storage / your backend here
        // and call user.updatePhotoURL(uploadedUrl) once you have a URL.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось выбрать фото: $e'),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.updateDisplayName(_nameController.text.trim());
      await user?.reload();
      // TODO: persist phone/telegram/avatar URL to your backend (Firestore, etc.)
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Профиль обновлён'),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Выйти из аккаунта?',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите выйти?',
          style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8A8A8E)),
        ),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 1.5.h),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Отмена',
                    style: TextStyle(color: Colors.black, fontSize: 13.sp)),
              ),
            ),
            SizedBox(width: 2.5.w),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 1.5.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Выйти',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.sp)),
              ),
            ),
          ]),
        ],
        actionsPadding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Без имени';
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        title: Text(
          'Профиль',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 18.sp,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (!_isEditing)
            Padding(
              padding: EdgeInsets.only(right: 4.w),
              child: TextButton(
                onPressed: () => setState(() => _isEditing = true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                ),
                child: Text('Изменить',
                    style: TextStyle(
                        fontSize: 13.sp, fontWeight: FontWeight.w700)),
              ),
            ),
          if (_isEditing)
            Padding(
              padding: EdgeInsets.only(right: 4.w),
              child: TextButton(
                onPressed: () => setState(() => _isEditing = false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8A8A8E),
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                ),
                child: Text('Отмена',
                    style: TextStyle(
                        fontSize: 13.sp, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEFEFEF)),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(5.w),
        child: Column(
          children: [
            SizedBox(height: 1.5.h),

            // ── Аватар ───────────────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _isEditing ? _pickAvatar : null,
                child: Stack(
                  children: [
                    Container(
                      width: 24.w,
                      height: 24.w,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        image: _avatarFile != null
                            ? DecorationImage(
                                image: FileImage(_avatarFile!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _avatarFile == null
                          ? Center(
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 7.5.w,
                          height: 7.5.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Icon(Icons.camera_alt_rounded,
                              color: Colors.black, size: 1.8.h),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 1.2.h),

            Text(
              displayName,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 0.3.h),
            Text(
              user?.email ?? 'Нет email',
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF8A8A8E),
              ),
            ),

            SizedBox(height: 3.5.h),

            // ── Поля ─────────────────────────────────────────────────────────
            const _SectionLabel(label: 'Личные данные'),
            SizedBox(height: 1.2.h),

            _ProfileField(
              label: 'Имя',
              controller: _nameController,
              icon: Icons.person_outline_rounded,
              enabled: _isEditing,
              hint: 'Введите ваше имя',
            ),
            SizedBox(height: 1.5.h),
            _ProfileField(
              label: 'Телефон',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              enabled: _isEditing,
              hint: '+7 (___) ___-__-__',
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 1.5.h),
            _ProfileField(
              label: 'Telegram',
              controller: _telegramController,
              icon: Icons.send_outlined,
              enabled: _isEditing,
              hint: '@username',
              keyboardType: TextInputType.text,
            ),

            SizedBox(height: 3.5.h),

            // ── Кнопка сохранить ─────────────────────────────────────────────
            if (_isEditing)
              SizedBox(
                width: double.infinity,
                height: 6.5.h,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3.5.w)),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 2.5.h,
                          height: 2.5.h,
                          child: const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Сохранить',
                          style: TextStyle(
                              fontSize: 15.sp, fontWeight: FontWeight.w700),
                        ),
                ),
              ),

            if (_isEditing) SizedBox(height: 1.5.h),

            // ── Кнопка выйти ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 6.5.h,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: Icon(Icons.logout_rounded, size: 2.2.h, color: Colors.black),
                label: Text(
                  'Выйти из аккаунта',
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black, width: 1.2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.5.w)),
                ),
              ),
            ),

            SizedBox(height: 3.h),
          ],
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8A8A8E),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Profile field ──────────────────────────────────────────────────────────────

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final String hint;
  final TextInputType keyboardType;

  const _ProfileField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.enabled,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(3.5.w),
        border: Border.all(
          color: enabled ? Colors.black : const Color(0xFFEFEFEF),
          width: enabled ? 1.2 : 1,
        ),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        cursorColor: Colors.black,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 12.sp,
            color: const Color(0xFF8A8A8E),
          ),
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 13.sp,
            color: const Color(0xFFB0B0B0),
          ),
          prefixIcon: Icon(
            icon,
            color: enabled ? Colors.black : const Color(0xFFB0B0B0),
            size: 2.4.h,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3.5.w),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3.5.w),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3.5.w),
            borderSide: BorderSide.none,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3.5.w),
            borderSide: BorderSide.none,
          ),
          filled: false,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
        ),
      ),
    );
  }
}