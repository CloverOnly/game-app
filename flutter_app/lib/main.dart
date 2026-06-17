import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/menu_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const LandGrabberApp());
}

class LandGrabberApp extends StatelessWidget {
  const LandGrabberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '대격돌! 땅따먹기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A90D9)),
        useMaterial3: true,
      ),
      home: const MenuScreen(),
    );
  }
}
