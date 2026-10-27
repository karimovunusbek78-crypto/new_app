import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_app/src/app/app_theme.dart';
import 'package:new_app/src/app/ui_kit.dart';
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
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
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
      debugPrint(
        'FirebaseAuthException code: ${e.code}, message: ${e.message}',
      );
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

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email)) {
      setState(
        () => _errorMessage = 'Введите email, чтобы восстановить пароль',
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _errorMessage = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Письмо для сброса пароля отправлено на $email'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = 'Не удалось отправить письмо: ${e.code}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'С возвращением 👋',
      subtitle: 'Войдите, чтобы продолжить',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthErrorBanner(message: _errorMessage),
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: AuthInputField(
                controller: _emailController,
                label: 'Email',
                hint: 'name@mail.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите email';
                  if (!RegExp(
                    r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$',
                  ).hasMatch(v.trim()))
                    return 'Неверный формат email';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 170),
              child: AuthInputField(
                controller: _passwordController,
                label: 'Пароль',
                hint: 'Ваш пароль',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите пароль';
                  if (v.length < 6) return 'Минимум 6 символов';
                  return null;
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resetPassword,
                child: const Text(
                  'Забыли пароль?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 240),
              child: GradientButton(
                label: 'Войти',
                icon: Icons.arrow_forward_rounded,
                loading: _isLoading,
                onPressed: _signIn,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: AuthSwitchLink(
                text: 'Нет аккаунта? ',
                action: 'Зарегистрироваться',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUp()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

/// Общий каркас экранов входа/регистрации: градиентная "шапка" с логотипом
/// и белый лист с формой, который выезжает снизу.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primaryDeep,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2D1B6E),
                  Color(0xFF4B3BD6),
                  Color(0xFF3A6FF8),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Декоративные "пятна" света
                Positioned(top: -60, right: -40, child: _glowCircle(200, 0.12)),
                Positioned(top: 120, left: -70, child: _glowCircle(160, 0.08)),
                // Белый "пол", чтобы под листом с формой не просвечивал градиент
                // при коротком контенте или overscroll'е.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: const ColoredBox(color: Colors.white),
                ),
                SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: topPad + 12),
                        if (showBack)
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Pressable(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 44),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: FadeSlideIn(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppLogo(size: 72),
                                const SizedBox(height: 20),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.8,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 60),
                          offset: const Offset(0, 60),
                          duration: const Duration(milliseconds: 650),
                          child: Container(
                            width: double.infinity,
                            constraints: BoxConstraints(
                              minHeight:
                                  MediaQuery.of(context).size.height * 0.62,
                            ),
                            padding: EdgeInsets.fromLTRB(
                              24,
                              28,
                              24,
                              24 + MediaQuery.of(context).padding.bottom,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(32),
                              ),
                            ),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glowCircle(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

/// Плашка ошибки, которая плавно раскрывается/скрывается.
class AuthErrorBanner extends StatelessWidget {
  final String? message;
  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: message == null
            ? const SizedBox(width: double.infinity)
            : Container(
                key: ValueKey(message),
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message!,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class AuthSwitchLink extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onTap;

  const AuthSwitchLink({
    super.key,
    required this.text,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: RichText(
          text: TextSpan(
            text: text,
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
            children: [
              TextSpan(
                text: action,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthLabel extends StatelessWidget {
  final String text;
  const AuthLabel({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}

class AuthInputField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;

  const AuthInputField({
    Key? key,
    required this.controller,
    this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: AppColors.muted, size: 20),
        suffixIcon: suffixIcon,
        fillColor: AppColors.surfaceAlt,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthLabel(text: label!),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}
