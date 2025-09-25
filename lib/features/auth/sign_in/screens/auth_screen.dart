import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:jala_form/features/auth/sign_in/screens/mobile_auth_screen.dart';
import 'package:jala_form/features/auth/sign_in/screens/web_auth_screen.dart';



class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WebAuthScreen();
    }

    else {
      return const MobileAuthScreen();
    }



  }
}
