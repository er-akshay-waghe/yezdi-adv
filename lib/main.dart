import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/profile_provider.dart';
import 'screens/splash_screen.dart';
import 'services/background_navigation_service.dart';
import 'services/bluetooth_service.dart';
import 'services/dashboard_status_service.dart';
import 'services/navigation_service.dart';
import 'services/performance_monitor_service.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PerformanceMonitorService.instance.start();
  try {
    await BackgroundNavigationService.configure();
  } catch (_) {}
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => BikeBluetoothService()..initializeAutoConnect()),
        ChangeNotifierProvider(create: (_) => NavService()..initLocation()),
        ChangeNotifierProvider(
            create: (_) => DashboardStatusService()..initialize()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()..load()),
      ],
      child: const YezdiNavApp(),
    ),
  );
}

class YezdiNavApp extends StatelessWidget {
  const YezdiNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Yezdi',
      debugShowCheckedModeBanner: false,
      theme: buildYezdiTheme(),
      home: const SplashScreen(),
    );
  }
}
