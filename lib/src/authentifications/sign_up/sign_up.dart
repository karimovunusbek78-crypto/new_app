import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:new_app/src/authentifications/sign_in/sign_in.dart';

class SignUp extends StatefulWidget {
  const SignUp({Key? key}) : super(key: key);

  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Save display name
      await credential.user?.updateDisplayName(_nameController.text.trim());

      // AuthWrapper StreamBuilder detects login → rebuilds to MainNavBar.
      // SignUp was pushed on top of SignIn, so pop both back to the root
      // so AuthWrapper's new state becomes visible.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use': _errorMessage = 'Этот email уже используется'; break;
          case 'invalid-email': _errorMessage = 'Неверный формат email'; break;
          case 'weak-password': _errorMessage = 'Пароль слишком слабый'; break;
          default: _errorMessage = 'Ошибка регистрации. Попробуйте снова';
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 2.h),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 10.w, height: 10.w,
                    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1C1C1E)),
                  ),
                ),
                SizedBox(height: 4.h),
                Text('Создать аккаунт', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E), letterSpacing: -0.5)),
                SizedBox(height: 0.8.h),
                Text('Зарегистрируйтесь для продолжения', style: TextStyle(fontSize: 13.sp, color: const Color(0xFF9E9E9E))),
                SizedBox(height: 4.h),
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                    decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(12)),
                    child: Text(_errorMessage!, style: TextStyle(fontSize: 12.sp, color: const Color(0xFFD32F2F))),
                  ),
                  SizedBox(height: 2.h),
                ],
                AuthLabel(text: 'Имя'),
                SizedBox(height: 1.h),
                AuthInputField(
                  controller: _nameController,
                  hint: 'Введите ваше имя',
                  prefixIcon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.name,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Введите имя';
                    return null;
                  },
                ),
                SizedBox(height: 2.5.h),
                AuthLabel(text: 'Email'),
                SizedBox(height: 1.h),
                AuthInputField(
                  controller: _emailController,
                  hint: 'Введите ваш email',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите email';
                    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v)) return 'Неверный формат email';
                    return null;
                  },
                ),
                SizedBox(height: 2.5.h),
                AuthLabel(text: 'Пароль'),
                SizedBox(height: 1.h),
                AuthInputField(
                  controller: _passwordController,
                  hint: 'Введите пароль',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF9E9E9E), size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите пароль';
                    if (v.length < 6) return 'Минимум 6 символов';
                    return null;
                  },
                ),
                SizedBox(height: 2.5.h),
                AuthLabel(text: 'Подтвердите пароль'),
                SizedBox(height: 1.h),
                AuthInputField(
                  controller: _confirmController,
                  hint: 'Повторите пароль',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirm,
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    child: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF9E9E9E), size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Подтвердите пароль';
                    if (v != _passwordController.text) return 'Пароли не совпадают';
                    return null;
                  },
                ),
                SizedBox(height: 4.h),
                SizedBox(
                  width: double.infinity, height: 7.h,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1C1E), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Создать аккаунт', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(height: 3.h),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: RichText(
                      text: TextSpan(
                        text: 'Уже есть аккаунт? ',
                        style: TextStyle(fontSize: 13.sp, color: const Color(0xFF9E9E9E)),
                        children: [TextSpan(text: 'Войти', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF2D1B6E)))],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 3.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}