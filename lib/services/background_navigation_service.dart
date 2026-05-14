import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';

class BackgroundNavigationService {
  static Future<void> configure() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'yezdi_navigation',
        initialNotificationTitle: 'My Yezdi navigation',
        initialNotificationContent: 'Navigation is ready',
        foregroundServiceNotificationId: 4210,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  static Future<void> start() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  static Future<void> stop() async {
    FlutterBackgroundService().invoke('stop');
  }
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  service.on('stop').listen((_) => service.stopSelf());
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
