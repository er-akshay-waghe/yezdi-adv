import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/profile_provider.dart';
import 'screens/home_screen.dart';
import 'services/bluetooth_service.dart';
import 'services/navigation_service.dart';
import 'utils/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => BikeBluetoothService()..initializeAutoConnect()),
        ChangeNotifierProvider(create: (_) => NavService()..initLocation()),
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
      title: 'Yezdi Adventure',
      debugShowCheckedModeBanner: false,
      theme: buildYezdiTheme(),
      home: const HomeScreen(),
    );
  }
}
