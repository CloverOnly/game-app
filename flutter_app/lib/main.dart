import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _lockLandscape();
  runApp(const LandGrabberApp());
}

Future<void> _lockLandscape() {
  return SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

class LandGrabberApp extends StatefulWidget {
  const LandGrabberApp({super.key});

  @override
  State<LandGrabberApp> createState() => _LandGrabberAppState();
}

class _LandGrabberAppState extends State<LandGrabberApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockLandscape();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lockLandscape();
    }
  }

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
