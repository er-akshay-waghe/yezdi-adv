import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const String yezdiDeviceName = 'MY YEZDI';

const String serviceUuidTbt = 'd6328aea-d630-4a83-b51b-1da8e8da8200';
const String charUuidTbt = 'd6328aea-d630-4a83-b51b-1da8e8da8210';
const String charUuidDtm = 'd6328aea-d630-4a83-b51b-1da8e8da8220';
const String charUuidDtd = 'd6328aea-d630-4a83-b51b-1da8e8da8230';

enum NavDirection { straight, left, right, uTurn, arrive, roundabout }

enum BikeConnectionState { disconnected, connecting, connected }

class BleScanDevice {
  final BluetoothDevice device;
  final String name;

  const BleScanDevice({required this.device, required this.name});
}

class BikeBluetoothService extends ChangeNotifier {
  BluetoothDevice? _connectedDevice;
  final List<BleScanDevice> _scannedDevices = [];
  final List<String> _txLog = [];

  bool _isBluetoothOn = false;
  bool _isScanning = false;
  bool _autoConnectEnabled = true;
  bool _manualDisconnect = false;
  String _status = 'Bluetooth idle';
  BikeConnectionState _connectionState = BikeConnectionState.disconnected;

  StreamSubscription? _scanSub;
  StreamSubscription? _scanStateSub;
  StreamSubscription? _adapterStateSub;
  StreamSubscription? _connectionSub;
  Timer? _reconnectTimer;

  List<BleScanDevice> get scannedDevices => List.unmodifiable(_scannedDevices);
  List<String> get txLog => List.unmodifiable(_txLog);
  bool get isBluetoothOn => _isBluetoothOn;
  bool get isScanning => _isScanning;
  bool get isConnected => _connectionState == BikeConnectionState.connected;
  bool get isConnecting => _connectionState == BikeConnectionState.connecting;
  bool get autoConnectEnabled => _autoConnectEnabled;
  String get status => _status;
  BikeConnectionState get connectionState => _connectionState;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  Future<void> initializeAutoConnect() async {
    _adapterStateSub ??= FlutterBluePlus.adapterState.listen((state) {
      _isBluetoothOn = state == BluetoothAdapterState.on;
      if (!_isBluetoothOn) {
        _status = 'Bluetooth disabled';
        _isScanning = false;
        _connectionState = BikeConnectionState.disconnected;
      } else if (!isConnected && _autoConnectEnabled) {
        _status = 'Searching for $yezdiDeviceName';
        startScan(autoConnect: true);
      }
      notifyListeners();
    });

    final granted = await requestPermissions();
    if (granted) {
      await startScan(autoConnect: true);
    } else {
      _status = 'Bluetooth permissions required';
      notifyListeners();
    }
  }

  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<void> startScan({bool autoConnect = false}) async {
    if (_isScanning || isConnected || isConnecting) return;
    _autoConnectEnabled = _autoConnectEnabled || autoConnect;

    final granted = await requestPermissions();
    if (!granted) {
      _status = 'Bluetooth permissions required';
      notifyListeners();
      return;
    }

    _scannedDevices.clear();
    _isScanning = true;
    _status = autoConnect
        ? 'Auto scanning for $yezdiDeviceName'
        : 'Scanning for bikes';
    notifyListeners();

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen(_handleScanResults);

    _scanStateSub ??= FlutterBluePlus.isScanning.listen((scanning) {
      _isScanning = scanning;
      if (!scanning && !isConnected && !isConnecting) {
        _status = _autoConnectEnabled
            ? 'Bike not found. Retrying shortly'
            : 'Scan complete';
        _scheduleReconnectScan();
      }
      notifyListeners();
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
    } catch (e) {
      _isScanning = false;
      _status = 'Scan failed: $e';
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    _isScanning = false;
    notifyListeners();
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      final name = _resolveName(result);
      final known = _scannedDevices
          .any((d) => d.device.remoteId == result.device.remoteId);
      if (!known) {
        _scannedDevices.add(BleScanDevice(device: result.device, name: name));
      }

      if (_autoConnectEnabled &&
          name.toUpperCase() == yezdiDeviceName &&
          !isConnected &&
          !isConnecting) {
        connectToDevice(result.device, displayName: name);
        break;
      }
    }
    notifyListeners();
  }

  String _resolveName(ScanResult result) {
    final advName = result.advertisementData.advName;
    final platformName = result.device.platformName;
    if (advName.isNotEmpty) return advName;
    if (platformName.isNotEmpty) return platformName;
    return 'Unknown Device';
  }

  Future<void> connectToDevice(BluetoothDevice device,
      {String? displayName}) async {
    if (isConnecting) return;
    _manualDisconnect = false;
    _connectionState = BikeConnectionState.connecting;
    _status = 'Connecting to ${displayName ?? device.platformName}';
    notifyListeners();

    try {
      await FlutterBluePlus.stopScan();
      await device.connect(
          timeout: const Duration(seconds: 12), autoConnect: false);
      _connectedDevice = device;

      try {
        await device.requestMtu(247);
      } catch (_) {}

      _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected &&
            !_manualDisconnect) {
          _connectedDevice = null;
          _connectionState = BikeConnectionState.disconnected;
          _status = 'Bike disconnected. Reconnecting';
          notifyListeners();
          _scheduleReconnectScan();
        }
      });

      _connectionState = BikeConnectionState.connected;
      _status = 'Connected to $yezdiDeviceName';
      _log('SYS', [0], label: 'connected');
      notifyListeners();
    } catch (e) {
      _connectedDevice = null;
      _connectionState = BikeConnectionState.disconnected;
      _status = 'Connection failed. Retrying';
      notifyListeners();
      _scheduleReconnectScan();
    }
  }

  void _scheduleReconnectScan() {
    if (!_autoConnectEnabled ||
        _manualDisconnect ||
        isConnected ||
        isConnecting) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer =
        Timer(const Duration(seconds: 4), () => startScan(autoConnect: true));
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _autoConnectEnabled = false;
    _reconnectTimer?.cancel();
    await stopScan();
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _connectionState = BikeConnectionState.disconnected;
    _status = 'Disconnected';
    notifyListeners();
  }

  Future<void> enableAutoConnect() async {
    _manualDisconnect = false;
    _autoConnectEnabled = true;
    await startScan(autoConnect: true);
  }

  Future<bool> sendNavigation({
    required int signal,
    required int dtmMeters,
    required int dtdKm,
    required int dtdM,
  }) async {
    if (!isConnected || _connectedDevice == null) return false;

    try {
      final services = await _connectedDevice!.discoverServices();
      final tbtService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == serviceUuidTbt,
      );
      final tbtChar = tbtService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == charUuidTbt,
      );
      final dtmChar = tbtService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == charUuidDtm,
      );
      final dtdChar = tbtService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == charUuidDtd,
      );

      final signalBytes = [signal & 0xFF];
      final dtmBytes = [dtmMeters & 0xFF, (dtmMeters >> 8) & 0xFF];
      final dtdBytes = [dtdKm & 0xFF, (dtdKm >> 8) & 0xFF, dtdM & 0xFF];

      // Keep the reverse-engineered cluster write order exactly as observed.
      await tbtChar.write(signalBytes, withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 40));
      await dtmChar.write(dtmBytes, withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 40));
      await dtdChar.write(dtdBytes, withoutResponse: false);

      _log('NAV', [...signalBytes, ...dtmBytes, ...dtdBytes],
          label: 'signal $signal');
      return true;
    } catch (e) {
      debugPrint('NAV ERROR: $e');
      return false;
    }
  }

  Future<bool> sendStartNavigation() =>
      sendNavigation(signal: 100, dtmMeters: 0, dtdKm: 0, dtdM: 0);
  Future<bool> sendStopNavigation() =>
      sendNavigation(signal: 41, dtmMeters: 0, dtdKm: 0, dtdM: 0);
  Future<bool> sendArrival() =>
      sendNavigation(signal: 36, dtmMeters: 0, dtdKm: 0, dtdM: 0);

  void _log(String dir, List<int> bytes, {String label = ''}) {
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _txLog.insert(0, '$time  $dir  $hex  ${label.isEmpty ? '' : '// $label'}');
    if (_txLog.length > 80) _txLog.removeLast();
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _scanSub?.cancel();
    _scanStateSub?.cancel();
    _adapterStateSub?.cancel();
    _connectionSub?.cancel();
    _connectedDevice?.disconnect();
    super.dispose();
  }
}
