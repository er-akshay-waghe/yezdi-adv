import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/route_models.dart';
import '../utils/formatters.dart';
import 'bluetooth_service.dart';

const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

class NavService extends ChangeNotifier {
  Position? _currentPosition;
  List<RouteOption> _routeOptions = [];
  RouteOption? _activeRoute;
  int _selectedRouteIndex = 0;
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  bool _isLoadingRoute = false;
  String _error = '';
  double _remainingDistanceMeters = 0;

  StreamSubscription<Position>? _positionSub;
  DateTime _lastBleWrite = DateTime.fromMillisecondsSinceEpoch(0);
  int? _lastSignal;
  int? _lastDtmBucket;

  Position? get currentPosition => _currentPosition;
  List<RouteOption> get routeOptions => List.unmodifiable(_routeOptions);
  RouteOption? get activeRoute => _activeRoute;
  int get selectedRouteIndex => _selectedRouteIndex;
  List<NavStep> get steps => _activeRoute?.steps ?? const [];
  NavStep? get currentStep =>
      steps.isNotEmpty && _currentStepIndex < steps.length
          ? steps[_currentStepIndex]
          : null;
  int get currentStepIndex => _currentStepIndex;
  bool get isNavigating => _isNavigating;
  bool get isLoadingRoute => _isLoadingRoute;
  List<LatLng> get polylinePoints => _activeRoute?.polyline ?? const [];
  double get remainingDistanceMeters => _remainingDistanceMeters;
  double get remainingDistanceKm => _remainingDistanceMeters / 1000;
  String get error => _error;

  int get distanceToNextStep {
    final step = currentStep;
    final pos = _currentPosition;
    if (step == null || pos == null) return 0;
    return _distanceMeters(
      pos.latitude,
      pos.longitude,
      step.endLocation.latitude,
      step.endLocation.longitude,
    ).round();
  }

  Future<bool> initLocation() async {
    _error = '';
    if (!await Geolocator.isLocationServiceEnabled()) {
      _error = 'Location services are disabled';
      notifyListeners();
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _error = 'Location permission required';
      notifyListeners();
      return false;
    }
    _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    notifyListeners();
    return true;
  }

  Future<void> fetchRoutes(LatLng destination,
      {String travelMode = 'driving'}) async {
    if (_currentPosition == null && !await initLocation()) return;
    _isLoadingRoute = true;
    _error = '';
    notifyListeners();

    final origin =
        '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final dest = '${destination.latitude},${destination.longitude}';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$dest&mode=$travelMode&alternatives=true&key=$googleMapsApiKey&language=en',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        _error = 'Directions API error ${response.statusCode}';
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        _error = 'No route found: ${data['status']}';
        return;
      }
      final routes = data['routes'] as List;
      _routeOptions = routes
          .map((r) => _parseRoute(r as Map<String, dynamic>, destination))
          .toList();
      selectRoute(0, notify: false);
    } catch (e) {
      _error = 'Route fetch failed: $e';
    } finally {
      _isLoadingRoute = false;
      notifyListeners();
    }
  }

  Future<void> fetchRoute(LatLng destination, {String travelMode = 'driving'}) {
    return fetchRoutes(destination, travelMode: travelMode);
  }

  void selectRoute(int index, {bool notify = true}) {
    if (index < 0 || index >= _routeOptions.length) return;
    _selectedRouteIndex = index;
    _activeRoute = _routeOptions[index];
    _remainingDistanceMeters = _activeRoute!.distanceMeters.toDouble();
    _currentStepIndex = 0;
    if (notify) notifyListeners();
  }

  void startNavigation(BikeBluetoothService btService) {
    if (_activeRoute == null || _isNavigating) return;
    _isNavigating = true;
    _currentStepIndex = 0;
    _lastSignal = null;
    _lastDtmBucket = null;
    btService.sendStartNavigation();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((pos) => _onLocationUpdate(pos, btService));
    notifyListeners();
  }

  void stopNavigation({BikeBluetoothService? btService}) {
    _isNavigating = false;
    _positionSub?.cancel();
    _positionSub = null;
    btService?.sendStopNavigation();
    notifyListeners();
  }

  void _onLocationUpdate(Position pos, BikeBluetoothService btService) {
    _currentPosition = pos;
    final route = _activeRoute;
    if (route == null || route.steps.isEmpty) return;

    var step = route.steps[_currentStepIndex];
    var distToStep = _distanceMeters(pos.latitude, pos.longitude,
        step.endLocation.latitude, step.endLocation.longitude);
    if (distToStep < 18 && _currentStepIndex < route.steps.length - 1) {
      _currentStepIndex++;
      step = route.steps[_currentStepIndex];
      distToStep = _distanceMeters(pos.latitude, pos.longitude,
          step.endLocation.latitude, step.endLocation.longitude);
    }

    final finalDistance = _distanceMeters(
      pos.latitude,
      pos.longitude,
      route.destination.latitude,
      route.destination.longitude,
    );
    if (finalDistance < 25) {
      _remainingDistanceMeters = 0;
      btService.sendArrival();
      stopNavigation();
      notifyListeners();
      return;
    }

    var remaining = distToStep;
    for (var i = _currentStepIndex + 1; i < route.steps.length; i++) {
      remaining += route.steps[i].distanceMeters;
    }
    _remainingDistanceMeters = remaining;
    _sendBleStep(btService, step, distToStep.round(), remaining);
    notifyListeners();
  }

  void _sendBleStep(BikeBluetoothService btService, NavStep step, int dtmMeters,
      double dtdMeters) {
    final signal = _maneuverToYezdiSignal(step.maneuver, step.instruction);
    final dtmBucket = (dtmMeters / 20).round();
    final now = DateTime.now();
    final shouldSend = signal != _lastSignal ||
        dtmBucket != _lastDtmBucket ||
        now.difference(_lastBleWrite) > const Duration(seconds: 8);
    if (!shouldSend) return;

    final dtd = splitDtdMeters(dtdMeters);
    btService.sendNavigation(
      signal: signal,
      dtmMeters: dtmMeters.clamp(0, 65535).toInt(),
      dtdKm: dtd.km,
      dtdM: dtd.hundreds,
    );
    _lastSignal = signal;
    _lastDtmBucket = dtmBucket;
    _lastBleWrite = now;
  }

  int _maneuverToYezdiSignal(String maneuver, String instruction) {
    final m = maneuver.toLowerCase();
    final text = instruction.toLowerCase();
    if (m.contains('arrive') || text.contains('destination')) {
      return 36;
    }
    if (m.contains('roundabout')) {
      return _roundaboutSignal(m);
    }
    if (m.contains('uturn') || text.contains('u-turn')) {
      return 17;
    }
    if (m.contains('sharp-left')) {
      return 21;
    }
    if (m.contains('sharp-right')) {
      return 7;
    }
    if (m.contains('slight-left') ||
        m.contains('ramp-left') ||
        m.contains('fork-left') ||
        m.contains('merge-left')) {
      return 13;
    }
    if (m.contains('slight-right') ||
        m.contains('ramp-right') ||
        m.contains('fork-right') ||
        m.contains('merge-right')) {
      return 9;
    }
    if (m.contains('left') || text.contains(' left')) {
      return 5;
    }
    if (m.contains('right') || text.contains(' right')) {
      return 3;
    }
    return 1;
  }

  int _roundaboutSignal(String maneuver) {
    if (maneuver.contains('roundabout')) {
      return 39;
    }
    return 1;
  }

  RouteOption _parseRoute(Map<String, dynamic> route, LatLng destination) {
    final leg = (route['legs'] as List).first as Map<String, dynamic>;
    final steps = (leg['steps'] as List).map((raw) {
      final step = raw as Map<String, dynamic>;
      return NavStep(
        instruction: _stripHtml(step['html_instructions'] as String? ?? ''),
        maneuver: step['maneuver'] as String? ?? 'straight',
        distanceMeters: (step['distance']?['value'] as num? ?? 0).round(),
        startLocation: _latLng(step['start_location']),
        endLocation: _latLng(step['end_location']),
      );
    }).toList();

    return RouteOption(
      summary: route['summary'] as String? ?? 'Best route',
      distanceMeters: (leg['distance']?['value'] as num? ?? 0).round(),
      durationSeconds: (leg['duration']?['value'] as num? ?? 0).round(),
      polyline: _decodePolyline(
          route['overview_polyline']?['points'] as String? ?? ''),
      steps: steps,
      destination: destination,
    );
  }

  LatLng _latLng(dynamic json) {
    return LatLng(
        (json['lat'] as num).toDouble(), (json['lng'] as num).toDouble());
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return radius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }
}
