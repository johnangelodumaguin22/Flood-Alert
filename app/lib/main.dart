import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Api.instance.restoreSession();
  runApp(const FloodAlertApp());
}

class FloodAlertApp extends StatelessWidget {
  const FloodAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flood Alert System',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Api.instance.signedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
