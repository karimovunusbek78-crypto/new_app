import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_app/src/app/ui_kit.dart';
import 'package:new_app/src/authentifications/sign_in/sign_in.dart';
import 'package:new_app/src/pages/nav%20bar/main_nav_bar.dart';
import 'package:new_app/src/pages/welcome/welcome_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showWelcome = true;

  void _onWelcomeDone() {
    setState(() => _showWelcome = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final Widget child;
        if (snapshot.connectionState == ConnectionState.waiting) {
          child = const _Splash(key: ValueKey('splash'));
        } else if (snapshot.hasData && snapshot.data != null) {
          // Logged in → go to home
          child = const MainNavBar(key: ValueKey('home'));
        } else if (_showWelcome) {
          // Not logged in → welcome first, then sign in
          child = WelcomePage(
            key: const ValueKey('welcome'),
            onDone: _onWelcomeDone,
          );
        } else {
          child = const SignIn(key: ValueKey('signin'));
        }

        // Плавная смена экрана при входе/выходе вместо резкого "прыжка".
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween(begin: 0.97, end: 1.0).animate(anim),
              child: child,
            ),
          ),
          child: child,
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.scale(
            scale: v,
            child: Opacity(opacity: v.clamp(0, 1), child: child),
          ),
          child: const AppLogo(size: 120),
        ),
      ),
    );
  }
}
