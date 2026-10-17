import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2D1B6E),
                strokeWidth: 2,
              ),
            ),
          );
        }

        // Logged in → go to home
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavBar();
        }

        // Not logged in → welcome first, then sign in
        if (_showWelcome) {
          return WelcomePage(onDone: _onWelcomeDone);
        }

        return const SignIn();
      },
    );
  }
}