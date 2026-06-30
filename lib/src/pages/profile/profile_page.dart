import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_app/src/pages/profile/service/profile_history_service.dart';
import 'package:new_app/src/pages/favorite/favorite_page.dart';
import 'package:new_app/src/pages/settings/settings_page.dart';
import 'package:responsive_sizer/responsive_sizer.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _telegramController;

  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ProfileHistoryService _historyService = ProfileHistoryService();

  File? _avatarFile;
  // URL of the avatar already stored in Firestore/Storage, used as a
  // fallback display when the user hasn't picked a new local file.
  String? _avatarUrl;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoadingProfile = true;
  // True while a freshly picked photo is being uploaded to Storage.
  bool _isUploadingAvatar = false;

  // Email the user originally had when they entered edit mode —
  // used to detect whether they actually changed it and to reauthenticate.
  String _originalEmail = '';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController();
    _telegramController = TextEditingController();
    _originalEmail = user?.email ?? '';
    _loadProfileFromFirestore();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  /// Loads the extra profile fields (phone, telegram, avatarUrl) that live
  /// in the `users` Firestore collection, keyed by the auth uid.
  Future<void> _loadProfileFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _phoneController.text = (data['phone'] ?? '') as String;
        _telegramController.text = (data['telegram'] ?? '') as String;
        final rawAvatarUrl = data['avatarUrl'] as String?;
        // An empty string ("") is not the same as no avatar — treat it
        // as null so the initials fallback shows instead of a blank circle.
        _avatarUrl = (rawAvatarUrl != null && rawAvatarUrl.isNotEmpty) ? rawAvatarUrl : null;
      }
    } catch (e) {
      _showSnack('Не удалось загрузить профиль: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
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
                if (_avatarFile != null || _avatarUrl != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Удалить фото',
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteAvatar();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Clears the local + remote avatar. The actual `users/{uid}` document
  /// (and history log) only get updated once the user hits "Сохранить",
  /// same as every other field on this screen.
  Future<void> _deleteAvatar() async {
    final oldUrl = _avatarUrl;
    setState(() {
      _avatarFile = null;
      _avatarUrl = null;
    });
    if (oldUrl != null) {
      try {
        await _storage.refFromURL(oldUrl).delete();
      } catch (_) {
        // File may already be gone — nothing to do.
      }
    }
  }

  Future<void> _getImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _avatarFile = file;
      _isUploadingAvatar = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      // Fixed path per user (not per-upload), so re-uploading a new photo
      // overwrites the old file in Storage instead of leaving it orphaned.
      final ext = picked.path.split('.').last.toLowerCase();
      final ref = _storage.ref().child('avatars/${user.uid}.$ext');

      await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/$ext'),
      ).timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          throw Exception(
              'Превышено время ожидания. Проверьте интернет-соединение и что Cloud Storage включён в Firebase Console.');
        },
      );
      final url = await ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _isUploadingAvatar = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        _showSnack('Не удалось загрузить фото: $e', isError: true);
      }
    }
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Asks the user for their current password and reauthenticates them.
  /// Returns true on success, false if cancelled or failed.
  Future<bool> _reauthenticate(String currentEmail) async {
    final passwordController = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Подтвердите пароль',
                style: TextStyle(
                    fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Для изменения email введите текущий пароль',
                    style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8A8A8E)),
                  ),
                  SizedBox(height: 2.h),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    autofocus: true,
                    cursorColor: Colors.black,
                    style: TextStyle(fontSize: 14.sp, color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Пароль',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFF8A8A8E),
                        ),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                    ),
                  ),
                ],
              ),
              actions: [
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Отмена', style: TextStyle(color: Colors.black, fontSize: 13.sp)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Подтвердить',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp)),
                    ),
                  ),
                ]),
              ],
              actionsPadding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
            );
          },
        );
      },
    );

    if (confirmed != true) return false;
    if (passwordController.text.isEmpty) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final credential = EmailAuthProvider.credential(
        email: currentEmail,
        password: passwordController.text,
      );
      await user?.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      _showSnack(_authErrorMessage(e), isError: true);
      return false;
    } catch (e) {
      _showSnack('Не удалось подтвердить пароль: $e', isError: true);
      return false;
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Неверный пароль';
      case 'invalid-email':
        return 'Некорректный email';
      case 'email-already-in-use':
        return 'Этот email уже используется другим аккаунтом';
      case 'requires-recent-login':
        return 'Требуется повторный вход. Попробуйте ещё раз';
      case 'too-many-requests':
        return 'Слишком много попыток. Попробуйте позже';
      default:
        return e.message ?? 'Произошла ошибка (${e.code})';
    }
  }

  Future<void> _saveProfile() async {
    final newEmail = _emailController.text.trim();

    if (newEmail.isEmpty || !newEmail.contains('@')) {
      _showSnack('Введите корректный email', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.updateDisplayName(_nameController.text.trim());

      final emailChanged = newEmail != _originalEmail;
      if (emailChanged && user != null) {
        await _updateEmail(user, newEmail);
      }

      await user?.reload();

      // Persist the profile (name, email, phone, telegram, photo) into the
      // `users` Firestore collection — and log every change permanently
      // into `users/{uid}/history` so nothing gets lost on overwrite.
      if (user != null) {
        await _historyService.saveProfile(user.uid, {
          'name': _nameController.text.trim(),
          'email': newEmail,
          'phone': _phoneController.text.trim(),
          'telegram': _telegramController.text.trim(),
          if (_avatarUrl != null) 'avatarUrl': _avatarUrl,
        });
      }

      setState(() {
        _isEditing = false;
        _isSaving = false;
        _originalEmail = FirebaseAuth.instance.currentUser?.email ?? _originalEmail;
      });

      if (emailChanged) {
        _showSnack('Профиль обновлён. Подтвердите новый email по ссылке из письма');
      } else {
        _showSnack('Профиль обновлён');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (e is FirebaseAuthException) {
        _showSnack(_authErrorMessage(e), isError: true);
      } else {
        _showSnack('Ошибка: $e', isError: true);
      }
    }
  }

  /// Updates the user's email, transparently handling the
  /// "requires-recent-login" case by prompting for the password once.
  Future<void> _updateEmail(User user, String newEmail) async {
    try {
      // verifyBeforeUpdateEmail sends a confirmation link to the NEW address;
      // the email only actually changes once the user clicks that link.
      // This is the Firebase-recommended approach (the old updateEmail()
      // call is deprecated/blocked on many projects for security reasons).
      await user.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        final currentEmail = _originalEmail;
        final reauthed = await _reauthenticate(currentEmail);
        if (reauthed) {
          await user.verifyBeforeUpdateEmail(newEmail);
        } else {
          // Revert the field so we don't show a "saved" state that didn't happen.
          _emailController.text = _originalEmail;
          rethrow;
        }
      } else {
        rethrow;
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

    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

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
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    // discard unsaved email edits
                    _emailController.text = _originalEmail;
                  });
                },
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
                onTap: (_isEditing && !_isUploadingAvatar) ? _pickAvatar : null,
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
                            : (_avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_avatarUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                      ),
                      child: (_avatarFile == null && _avatarUrl == null)
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
                    // Dim overlay + spinner while the picked photo is
                    // uploading to Firebase Storage.
                    if (_isUploadingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 3.h,
                              height: 3.h,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                        ),
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

            // ── Меню (Избранное / Активность / Настройки) ──────────────────────
            const _SectionLabel(label: 'Меню'),
            SizedBox(height: 1.2.h),

            _MenuTile(
              icon: Icons.favorite_border_rounded,
              label: 'Избранное',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritePage()),
              ),
            ),
            SizedBox(height: 1.2.h),
            _MenuTile(
              icon: Icons.history_rounded,
              label: 'Моя активность',
              onTap: () {
                // TODO: hook up to your activity/history page when ready
              },
            ),
            SizedBox(height: 1.2.h),
            _MenuTile(
              icon: Icons.settings_outlined,
              label: 'Настройки',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
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
              label: 'Email',
              controller: _emailController,
              icon: Icons.email_outlined,
              enabled: _isEditing,
              hint: 'example@mail.com',
              keyboardType: TextInputType.emailAddress,
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

            if (_isEditing && _emailController.text.trim() != _originalEmail)
              Padding(
                padding: EdgeInsets.only(top: 1.2.h),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'На новый email придёт письмо для подтверждения',
                    style: TextStyle(fontSize: 11.5.sp, color: const Color(0xFF8A8A8E)),
                  ),
                ),
              ),

            SizedBox(height: 3.5.h),

            // ── Кнопка сохранить ─────────────────────────────────────────────
            if (_isEditing)
              SizedBox(
                width: double.infinity,
                height: 6.5.h,
                child: ElevatedButton(
                  onPressed: (_isSaving || _isUploadingAvatar) ? null : _saveProfile,
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

// ── Menu tile (Избранное / Активность / Настройки) ──────────────────────────

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(3.5.w),
        border: Border.all(color: const Color(0xFFEFEFEF), width: 1),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3.5.w),
        ),
        leading: Icon(icon, color: Colors.black, size: 2.4.h),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded,
            color: const Color(0xFFB0B0B0), size: 2.4.h),
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.4.h),
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