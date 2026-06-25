import 'dart:io';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'services/foreground_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isIOS) {
    await NotificationService.init();
  }
  await ApiService.loadBaseUrl();
  await ApiService.loadToken();
  SocketService.startConnectivityMonitor();
  if (ApiService.token != null && !Platform.isIOS) {
    ForegroundServiceHelper.start();
  }
  runApp(const XCloneApp());
}

class XCloneApp extends StatelessWidget {
  const XCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'X',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1DA1F2)),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: ApiService.token != null ? const HomeScreen() : const LoginScreen(),
    );
  }
}
