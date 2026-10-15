import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:new_app/src/authentifications/sign_up/sign_up.dart';

class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  _SignInState createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // AuthWrapper StreamBuilder detects login → rebuilds to MainNavBar.
      // If SignIn was reached via Navigator.push (e.g. from SignUp), pop
      // back to the root so AuthWrapper's new state becomes visible.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException code: ${e.code}, message: ${e.message}');
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = 'Пользователь не найден';
            break;
          case 'wrong-password':
            _errorMessage = 'Неверный пароль';
            break;
          case 'invalid-email':
            _errorMessage = 'Неверный формат email';
            break;
          case 'too-many-requests':
            _errorMessage = 'Слишком много попыток. Попробуйте позже';
            break;
          case 'invalid-credential':
            _errorMessage = 'Неверный email или пароль';
            break;
          case 'user-disabled':
            _errorMessage = 'Аккаунт отключён';
            break;
          case 'network-request-failed':
            _errorMessage = 'Проблема с сетью. Проверьте интернет';
            break;
          default:
            _errorMessage = 'Ошибка входа: ${e.code}';
        }
      });
    } catch (e) {
      // Catches non-FirebaseAuthException errors (e.g. plugin/Pigeon bugs)
      debugPrint('Unexpected sign-in error: $e');
      setState(() {
        _errorMessage = 'Непредвиденная ошибка: $e';
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
                SizedBox(height: 6.h),
                Text('Добро пожаловать', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E), letterSpacing: -0.5)),
                SizedBox(height: 0.8.h),
                Text('Войдите, чтобы продолжить', style: TextStyle(fontSize: 13.sp, color: const Color(0xFF9E9E9E))),
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
                  hint: 'Введите ваш пароль',
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
                SizedBox(height: 4.h),
                SizedBox(
                  width: double.infinity, height: 7.h,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1C1E), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Войти', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(height: 3.h),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUp())),
                    child: RichText(
                      text: TextSpan(
                        text: 'Нет аккаунта? ',
                        style: TextStyle(fontSize: 13.sp, color: const Color(0xFF9E9E9E)),
                        children: [TextSpan(text: 'Зарегистрироваться', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF2D1B6E)))],
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

// ── Shared widgets ─────────────────────────────────────────────────────────

class AuthLabel extends StatelessWidget {
  final String text;
  const AuthLabel({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1E)));
  }
}

class AuthInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const AuthInputField({
    Key? key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(fontSize: 13.5.sp, color: const Color(0xFF1C1C1E)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13.sp, color: const Color(0xFFBBBBBB)),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF9E9E9E), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF7F7F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2D1B6E), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5)),
      ),
    );
  }
}