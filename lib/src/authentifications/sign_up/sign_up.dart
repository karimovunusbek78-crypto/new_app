import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:new_app/src/app/app_theme.dart';
import 'package:new_app/src/app/ui_kit.dart';
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
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      // Save display name
      await credential.user?.updateDisplayName(_nameController.text.trim());

      // Create the profile document right away: other features update it
      // (e.g. subscribersCount when someone follows this user), and an
      // update() on a missing document fails.
      final uid = credential.user?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'subscribersCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {
          // Not fatal: the account exists; the profile is filled in later.
        }
      }

      // AuthWrapper StreamBuilder detects login → rebuilds to MainNavBar.
      // SignUp was pushed on top of SignIn, so pop both back to the root
      // so AuthWrapper's new state becomes visible.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = 'Этот email уже используется';
            break;
          case 'invalid-email':
            _errorMessage = 'Неверный формат email';
            break;
          case 'weak-password':
            _errorMessage = 'Пароль слишком слабый';
            break;
          case 'network-request-failed':
            _errorMessage = 'Проблема с сетью. Проверьте интернет';
            break;
          default:
            _errorMessage = 'Ошибка регистрации. Попробуйте снова';
        }
      });
    } catch (e) {
      setState(() => _errorMessage = 'Непредвиденная ошибка: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget eye(bool obscure, VoidCallback toggle) => IconButton(
      onPressed: toggle,
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: AppColors.muted,
        size: 20,
      ),
    );

    final fields = <Widget>[
      AuthInputField(
        controller: _nameController,
        label: 'Имя',
        hint: 'Как к вам обращаться',
        prefixIcon: Icons.person_outline_rounded,
        keyboardType: TextInputType.name,
        textInputAction: TextInputAction.next,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Введите имя';
          return null;
        },
      ),
      AuthInputField(
        controller: _emailController,
        label: 'Email',
        hint: 'name@mail.com',
        prefixIcon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Введите email';
          if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v.trim()))
            return 'Неверный формат email';
          return null;
        },
      ),
      AuthInputField(
        controller: _passwordController,
        label: 'Пароль',
        hint: 'Минимум 6 символов',
        prefixIcon: Icons.lock_outline_rounded,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.next,
        suffixIcon: eye(
          _obscurePassword,
          () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Введите пароль';
          if (v.length < 6) return 'Минимум 6 символов';
          return null;
        },
      ),
      AuthInputField(
        controller: _confirmController,
        label: 'Подтвердите пароль',
        hint: 'Повторите пароль',
        prefixIcon: Icons.lock_outline_rounded,
        obscureText: _obscureConfirm,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _signUp(),
        suffixIcon: eye(
          _obscureConfirm,
          () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Подтвердите пароль';
          if (v != _passwordController.text) return 'Пароли не совпадают';
          return null;
        },
      ),
    ];

    return AuthScaffold(
      title: 'Создать аккаунт',
      subtitle: 'Пара шагов — и вы в Gravitas Auto',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthErrorBanner(message: _errorMessage),
            for (int i = 0; i < fields.length; i++) ...[
              FadeSlideIn(
                delay: FadeSlideIn.stagger(i + 1, stepMs: 70),
                child: fields[i],
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: FadeSlideIn.stagger(fields.length + 1, stepMs: 70),
              child: GradientButton(
                label: 'Создать аккаунт',
                icon: Icons.arrow_forward_rounded,
                loading: _isLoading,
                onPressed: _signUp,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: AuthSwitchLink(
                text: 'Уже есть аккаунт? ',
                action: 'Войти',
                onTap: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
