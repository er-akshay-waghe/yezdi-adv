import 'dart:async';
import 'dart:math';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';

import '../models/dashboard_status.dart';

@pragma('vm:entry-point')
void yezdiBackgroundSmsHandler(SmsMessage message) {}

class DashboardStatusService extends ChangeNotifier {
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final Telephony _telephony = Telephony.instance;

  final List<DashboardAlert> _alerts = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<ServiceNotificationEvent>? _notificationSub;
  Timer? _batteryTimer;
  Timer? _telephonyTimer;
  bool _disposed = false;
  CallState? _lastCallState;

  bool _isOnline = false;
  int _networkBars = 0;
  int _batteryLevel = 0;
  double _heading = 0;
  double _gpsAccuracyMeters = 999;
  bool _notificationAccess = false;

  List<DashboardAlert> get alerts => List.unmodifiable(_alerts);
  DashboardAlert? get latestAlert => _alerts.isEmpty ? null : _alerts.first;
  bool get isOnline => _isOnline;
  int get networkBars => _networkBars;
  int get batteryLevel => _batteryLevel;
  double get heading => _heading;
  double get gpsAccuracyMeters => _gpsAccuracyMeters;
  bool get notificationAccess => _notificationAccess;

  Future<void> initialize() async {
    await _refreshPermissions();
    await _refreshBattery();
    await _refreshConnectivity();
    _listenConnectivity();
    _listenCompass();
    _listenNotifications();
    _listenTelephony();
    _batteryTimer?.cancel();
    _batteryTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _refreshBattery(),
    );
  }

  void updateGpsAccuracy(double meters) {
    _gpsAccuracyMeters = meters;
    _safeNotify();
  }

  void clearLatestAlert() {
    if (_alerts.isEmpty) return;
    _alerts.removeAt(0);
    _safeNotify();
  }

  Future<void> requestNotificationAccess() async {
    try {
      final granted = await NotificationListenerService.isPermissionGranted();
      if (!granted) {
        await NotificationListenerService.requestPermission();
      }
      _notificationAccess =
          await NotificationListenerService.isPermissionGranted();
      _safeNotify();
    } catch (_) {}
  }

  Future<void> _refreshPermissions() async {
    await [
      Permission.notification,
      Permission.phone,
      Permission.sms,
      Permission.contacts,
    ].request();
    try {
      await _telephony.requestPhoneAndSmsPermissions;
    } catch (_) {}
    try {
      _notificationAccess =
          await NotificationListenerService.isPermissionGranted();
    } catch (_) {
      _notificationAccess = false;
    }
  }

  Future<void> _refreshBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _safeNotify();
    } catch (_) {}
  }

  Future<void> _refreshConnectivity() async {
    try {
      _applyConnectivity(await _connectivity.checkConnectivity());
    } catch (_) {}
  }

  void _listenConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      _applyConnectivity,
      onError: (_) {},
    );
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    _isOnline = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
    if (!_isOnline) {
      _networkBars = 0;
    } else if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet) ||
        results.contains(ConnectivityResult.vpn)) {
      _networkBars = 4;
    } else if (_networkBars == 0) {
      _networkBars = 2;
    }
    _safeNotify();
  }

  void _listenCompass() {
    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null || !heading.isFinite) return;
      _heading = (heading + 360) % 360;
      _safeNotify();
    });
  }

  void _listenNotifications() {
    _notificationSub?.cancel();
    _notificationSub = NotificationListenerService.notificationsStream.listen(
      (event) {
        final packageName = (event.packageName ?? '').toLowerCase();
        if (packageName.contains('whatsapp')) {
          _pushAlert(
            DashboardAlertType.app,
            event.title ?? 'WhatsApp',
            event.content ?? 'New message',
          );
        } else if (packageName.contains('dialer') ||
            packageName.contains('phone')) {
          _pushAlert(
            DashboardAlertType.call,
            event.title ?? 'Incoming call',
            event.content ?? 'Phone',
          );
        } else if (packageName.contains('messaging') ||
            packageName.contains('sms')) {
          _pushAlert(
            DashboardAlertType.sms,
            event.title ?? 'Message',
            event.content ?? 'New message',
          );
        }
      },
      onError: (_) {},
    );
  }

  void _listenTelephony() {
    try {
      _telephony.listenIncomingSms(
        onNewMessage: (message) {
          _pushAlert(
            DashboardAlertType.sms,
            message.address ?? 'SMS',
            message.body ?? 'New message',
          );
        },
        onBackgroundMessage: yezdiBackgroundSmsHandler,
        listenInBackground: true,
      );
    } catch (_) {}

    try {
      _telephonyTimer?.cancel();
      _telephonyTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _refreshTelephonyStatus(),
      );
      _refreshTelephonyStatus();
    } catch (_) {}
  }

  Future<void> _refreshTelephonyStatus() async {
    try {
      final state = await _telephony.callState;
      if (state == CallState.CALL_STATE_RINGING &&
          _lastCallState != CallState.CALL_STATE_RINGING) {
        _pushAlert(DashboardAlertType.call, 'Incoming call', 'Phone');
      }
      _lastCallState = state;
    } catch (_) {}

    try {
      final strengths = await _telephony.signalStrengths;
      if (strengths.isEmpty) return;
      _networkBars =
          strengths.map((signal) => signal.index).reduce(max).clamp(0, 4).toInt();
      _safeNotify();
    } catch (_) {}
  }

  void _pushAlert(DashboardAlertType type, String title, String body) {
    _alerts.insert(
      0,
      DashboardAlert(
        type: type,
        title: title.trim().isEmpty ? 'Notification' : title.trim(),
        body: body.trim(),
        timestamp: DateTime.now(),
      ),
    );
    if (_alerts.length > 5) _alerts.removeLast();
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivitySub?.cancel();
    _compassSub?.cancel();
    _notificationSub?.cancel();
    _batteryTimer?.cancel();
    _telephonyTimer?.cancel();
    super.dispose();
  }
}
