import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jala_form/features/home/screens/mobile_home.dart';
import 'package:jala_form/features/home/screens/web_home.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WebHomeScreen();
    }

    else {
      return const MobileHomeScreen();
    }



  }
}
