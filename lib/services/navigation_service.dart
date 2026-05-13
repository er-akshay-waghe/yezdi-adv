import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/google_maps_config.dart';
import '../models/route_models.dart';
import '../utils/formatters.dart';
import 'bluetooth_service.dart';

class NavService extends ChangeNotifier {
  Position? _currentPosition;
  LatLng? _rawLocation;
  LatLng? _smoothedLocation;
  LatLng? _targetLocation;
  List<RouteOption> _routeOptions = [];
  RouteOption? _activeRoute;
  int _selectedRouteIndex = 0;
  int _currentStepIndex = 0;
  int _nearestPolylineIndex = 0;
  bool _isNavigating = false;
  bool _isLoadingRoute = false;
  bool _isRerouting = false;
  bool _disposed = false;
  String _error = '';
  double _remainingDistanceMeters = 0;
  double _speedKmh = 0;
  double _bearing = 0;
  double _gpsAccuracyMeters = 999;
  int _offRouteSamples = 0;
  int _routeRequestId = 0;

  StreamSubscription<Position>? _positionSub;
  Timer? _markerTimer;
  DateTime _lastBleWrite = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRerouteAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDashboardNotify = DateTime.fromMillisecondsSinceEpoch(0);
  int? _lastSignal;
  int? _lastDtmBucket;

  Position? get currentPosition => _currentPosition;
  LatLng? get rawLocation => _rawLocation;
  LatLng? get smoothedLocation => _smoothedLocation ?? _rawLocation;
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
  bool get isRerouting => _isRerouting;
  List<LatLng> get polylinePoints => _activeRoute?.polyline ?? const [];
  double get remainingDistanceMeters => _remainingDistanceMeters;
  double get remainingDistanceKm => _remainingDistanceMeters / 1000;
  double get speedKmh => _speedKmh;
  double get bearing => _bearing;
  double get gpsAccuracyMeters => _gpsAccuracyMeters;
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

  int get etaSeconds {
    final route = _activeRoute;
    if (route == null || route.distanceMeters <= 0) return 0;
    final fraction =
        (_remainingDistanceMeters / route.distanceMeters).clamp(0.0, 1.0);
    final duration = route.durationInTrafficSeconds > 0
        ? route.durationInTrafficSeconds
        : route.durationSeconds;
    return (duration * fraction).round();
  }

  double get cameraZoom {
    if (_speedKmh > 85) return 15.6;
    if (_speedKmh > 55) return 16.2;
    if (_speedKmh > 25) return 17.0;
    return 17.8;
  }

  Future<bool> initLocation() async {
    _error = '';

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _error = 'Location services are disabled';
        _safeNotify(force: true);
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _error = 'Location permission required';
        _safeNotify(force: true);
        return false;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) _acceptPosition(lastKnown, notify: true);

      final fresh = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 12),
      );
      _acceptPosition(fresh, notify: true);
      return true;
    } catch (e) {
      _error = 'Location unavailable: $e';
      _safeNotify(force: true);
      return false;
    }
  }

  Future<void> fetchRoutes(
    LatLng destination, {
    String travelMode = 'driving',
  }) async {
    if (!hasGoogleMapsApiKey) {
      _error = 'Google Maps API key missing';
      _safeNotify(force: true);
      return;
    }
    if (_currentPosition == null && !await initLocation()) return;

    final requestId = ++_routeRequestId;
    _isLoadingRoute = !_isNavigating;
    _isRerouting = _isNavigating;
    _error = '';
    if (!_isNavigating) {
      _routeOptions = [];
      _activeRoute = null;
      _remainingDistanceMeters = 0;
    }
    _safeNotify(force: true);

    final origin =
        '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final dest = '${destination.latitude},${destination.longitude}';
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin': origin,
        'destination': dest,
        'mode': travelMode,
        'alternatives': 'true',
        'departure_time': 'now',
        'traffic_model': 'best_guess',
        'language': 'en',
        'key': googleMapsApiKey,
      },
    );

    try {
      final response = await _getWithRetry(uri);
      if (_disposed || requestId != _routeRequestId) return;

      if (response.statusCode != 200) {
        _error = 'Directions API error ${response.statusCode}';
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        _error = 'No route found: ${data['status'] ?? 'unknown error'}';
        return;
      }

      final routes = data['routes'] as List? ?? const [];
      final parsedRoutes = <RouteOption>[];
      for (var i = 0; i < routes.length; i++) {
        final route = routes[i];
        if (route is Map<String, dynamic>) {
          parsedRoutes.add(_parseGoogleRoute(route, destination, i));
        }
      }

      _routeOptions =
          parsedRoutes.where((route) => route.polyline.length > 1).toList();

      if (_routeOptions.isEmpty) {
        _error = 'Directions API returned an empty route';
        if (!_isNavigating) {
          _activeRoute = null;
          _remainingDistanceMeters = 0;
        }
      } else {
        selectRoute(0, notify: false);
      }
    } catch (e) {
      if (!_disposed && requestId == _routeRequestId) {
        _error = 'Route fetch failed: $e';
      }
    } finally {
      if (!_disposed && requestId == _routeRequestId) {
        _isLoadingRoute = false;
        _isRerouting = false;
        _safeNotify(force: true);
      }
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
    _nearestPolylineIndex = 0;
    _offRouteSamples = 0;
    if (notify) _safeNotify(force: true);
  }

  void startNavigation(BikeBluetoothService btService) {
    if (_activeRoute == null || _isNavigating) return;
    _isNavigating = true;
    _currentStepIndex = 0;
    _nearestPolylineIndex = 0;
    _lastSignal = null;
    _lastDtmBucket = null;
    _offRouteSamples = 0;
    _startMarkerSmoothing();
    btService.sendStartNavigation();

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen(
      (pos) => _onLocationUpdate(pos, btService),
      onError: (Object error) {
        _error = 'Location update failed: $error';
        _safeNotify(force: true);
      },
      cancelOnError: false,
    );
    _safeNotify(force: true);
  }

  void stopNavigation({BikeBluetoothService? btService}) {
    if (!_isNavigating && _positionSub == null) return;
    _isNavigating = false;
    _positionSub?.cancel();
    _positionSub = null;
    _stopMarkerSmoothing();
    _offRouteSamples = 0;
    btService?.sendStopNavigation();
    _safeNotify(force: true);
  }

  void _onLocationUpdate(Position pos, BikeBluetoothService btService) {
    _acceptPosition(pos);
    final route = _activeRoute;
    if (route == null || route.steps.isEmpty) {
      _safeNotify();
      return;
    }

    _nearestPolylineIndex = _nearestPolylinePointIndex(
      LatLng(pos.latitude, pos.longitude),
      route.polyline,
      startIndex: max(0, _nearestPolylineIndex - 15),
    );

    if (_currentStepIndex >= route.steps.length) {
      _currentStepIndex = route.steps.length - 1;
    }

    var step = route.steps[_currentStepIndex];
    var distToStep = _distanceMeters(
      pos.latitude,
      pos.longitude,
      step.endLocation.latitude,
      step.endLocation.longitude,
    );

    while (distToStep < 28 && _currentStepIndex < route.steps.length - 1) {
      _currentStepIndex++;
      step = route.steps[_currentStepIndex];
      distToStep = _distanceMeters(
        pos.latitude,
        pos.longitude,
        step.endLocation.latitude,
        step.endLocation.longitude,
      );
    }

    final finalDistance = _distanceMeters(
      pos.latitude,
      pos.longitude,
      route.destination.latitude,
      route.destination.longitude,
    );
    if (finalDistance < 30) {
      _remainingDistanceMeters = 0;
      btService.sendArrival();
      stopNavigation();
      _safeNotify(force: true);
      return;
    }

    _remainingDistanceMeters = _remainingDistanceFromPolyline(
      LatLng(pos.latitude, pos.longitude),
      route.polyline,
      _nearestPolylineIndex,
    );
    if (_remainingDistanceMeters <= 0) {
      _remainingDistanceMeters = finalDistance;
    }

    _sendBleStep(btService, step, distToStep.round(), _remainingDistanceMeters);
    _maybeReroute(pos);
    _safeNotify();
  }

  void _acceptPosition(Position pos, {bool notify = false}) {
    final next = LatLng(pos.latitude, pos.longitude);
    _currentPosition = pos;
    _rawLocation = next;
    _targetLocation = next;
    _smoothedLocation ??= next;
    _speedKmh = max(0, pos.speed * 3.6);
    _gpsAccuracyMeters = pos.accuracy;
    if (pos.heading.isFinite && pos.heading >= 0) {
      _bearing = pos.heading;
    } else if (_smoothedLocation != null) {
      _bearing = _bearingBetween(_smoothedLocation!, next);
    }
    if (notify) _safeNotify(force: true);
  }

  void _startMarkerSmoothing() {
    _markerTimer?.cancel();
    _markerTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final target = _targetLocation;
      final current = _smoothedLocation;
      if (!_isNavigating || target == null || current == null) return;

      final distance = _distanceMeters(
        current.latitude,
        current.longitude,
        target.latitude,
        target.longitude,
      );
      if (distance < 0.35) {
        _smoothedLocation = target;
      } else {
        _smoothedLocation = LatLng(
          _lerp(current.latitude, target.latitude, 0.22),
          _lerp(current.longitude, target.longitude, 0.22),
        );
      }
      _safeNotify();
    });
  }

  void _stopMarkerSmoothing() {
    _markerTimer?.cancel();
    _markerTimer = null;
    _smoothedLocation = _rawLocation;
  }

  void _maybeReroute(Position pos) {
    final route = _activeRoute;
    if (!_isNavigating || _isRerouting || route == null) return;

    final location = LatLng(pos.latitude, pos.longitude);
    final offRouteDistance = _distanceToNearestPoint(
      location,
      route.polyline,
      max(0, _nearestPolylineIndex - 25),
    );
    _offRouteSamples = offRouteDistance > 75 ? _offRouteSamples + 1 : 0;
    final canReroute =
        DateTime.now().difference(_lastRerouteAt) > const Duration(seconds: 18);

    if (_offRouteSamples < 3 || !canReroute) return;

    _lastRerouteAt = DateTime.now();
    fetchRoutes(route.destination).then((_) {
      if (_isNavigating) {
        _lastSignal = null;
        _lastDtmBucket = null;
      }
    });
  }

  void _sendBleStep(
    BikeBluetoothService btService,
    NavStep step,
    int dtmMeters,
    double dtdMeters,
  ) {
    final signal = maneuverToYezdiSignal(step.maneuver, step.instruction);
    final dtmBucket = (dtmMeters / 10).round();
    final now = DateTime.now();
    final shouldSend = signal != _lastSignal ||
        dtmBucket != _lastDtmBucket ||
        now.difference(_lastBleWrite) > const Duration(seconds: 4);
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

  int maneuverToYezdiSignal(String maneuver, String instruction) {
    final m = maneuver.toLowerCase().replaceAll('-', ' ');
    final text = instruction.toLowerCase();

    if (m.contains('arrive') || text.contains('destination')) return 36;
    if (m.contains('roundabout')) return 39;
    if (m.contains('uturn') || text.contains('u-turn')) return 17;
    if (m.contains('sharp right')) return 7;
    if (m.contains('sharp left')) return 21;
    if (m.contains('slight right') ||
        m.contains('ramp right') ||
        m.contains('fork right') ||
        m.contains('merge right')) {
      return 9;
    }
    if (m.contains('slight left') ||
        m.contains('ramp left') ||
        m.contains('fork left') ||
        m.contains('merge left')) {
      return 13;
    }
    if (m.contains('right') || text.contains(' right')) return 3;
    if (m.contains('left') || text.contains(' left')) return 5;
    return 1;
  }

  RouteOption _parseGoogleRoute(
    Map<String, dynamic> route,
    LatLng destination,
    int index,
  ) {
    final legs = route['legs'] as List? ?? const [];
    final leg = legs.isNotEmpty && legs.first is Map
        ? (legs.first as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final steps = (leg['steps'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_parseGoogleStep)
        .toList();
    final overview = route['overview_polyline']?['points'] as String? ?? '';
    final polyline = _decodePolyline(overview);
    final summary = (route['summary'] as String? ?? '').trim();

    return RouteOption(
      summary: summary.isEmpty ? _fallbackRouteSummary(index) : summary,
      distanceMeters: (leg['distance']?['value'] as num? ?? 0).round(),
      durationSeconds: (leg['duration']?['value'] as num? ?? 0).round(),
      durationInTrafficSeconds:
          (leg['duration_in_traffic']?['value'] as num? ?? 0).round(),
      polyline: polyline,
      steps: steps,
      destination: destination,
    );
  }

  NavStep _parseGoogleStep(Map<String, dynamic> step) {
    final stepPolyline = step['polyline']?['points'] as String? ?? '';
    return NavStep(
      instruction: _stripHtml(step['html_instructions'] as String? ?? ''),
      maneuver: step['maneuver'] as String? ?? 'straight',
      distanceMeters: (step['distance']?['value'] as num? ?? 0).round(),
      durationSeconds: (step['duration']?['value'] as num? ?? 0).round(),
      startLocation: _latLng(step['start_location']),
      endLocation: _latLng(step['end_location']),
      polyline: _decodePolyline(stepPolyline),
    );
  }

  LatLng _latLng(dynamic json) {
    final map = (json as Map?)?.cast<String, dynamic>() ?? const {};
    return LatLng(
      (map['lat'] as num? ?? 0).toDouble(),
      (map['lng'] as num? ?? 0).toDouble(),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    return PolylinePoints.decodePolyline(encoded)
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }

  String _fallbackRouteSummary(int index) {
    if (index == 0) return 'Fastest route';
    return 'Alternative ${index + 1}';
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.get(uri).timeout(
              const Duration(seconds: 12),
            );
        if (response.statusCode < 500 || attempt == 1) return response;
      } catch (e) {
        lastError = e;
      }
      await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }

    throw lastError ?? StateError('Directions request failed');
  }

  double _remainingDistanceFromPolyline(
    LatLng location,
    List<LatLng> points,
    int index,
  ) {
    if (points.isEmpty || index >= points.length) return 0;

    var remaining = _distanceMeters(
      location.latitude,
      location.longitude,
      points[index].latitude,
      points[index].longitude,
    );
    for (var i = index; i < points.length - 1; i++) {
      remaining += _distanceMeters(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return remaining;
  }

  int _nearestPolylinePointIndex(
    LatLng location,
    List<LatLng> points, {
    int startIndex = 0,
  }) {
    if (points.isEmpty) return 0;
    var nearestIndex = startIndex.clamp(0, points.length - 1).toInt();
    var nearestDistance = double.infinity;
    final end = min(points.length, nearestIndex + 120);

    for (var i = nearestIndex; i < end; i++) {
      final distance = _distanceMeters(
        location.latitude,
        location.longitude,
        points[i].latitude,
        points[i].longitude,
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  double _distanceToNearestPoint(
    LatLng location,
    List<LatLng> points,
    int startIndex,
  ) {
    if (points.isEmpty) return double.infinity;
    var nearest = double.infinity;
    final safeStart = startIndex.clamp(0, points.length - 1).toInt();
    final end = min(points.length, safeStart + 120);

    for (var i = safeStart; i < end; i++) {
      final distance = _distanceMeters(
        location.latitude,
        location.longitude,
        points[i].latitude,
        points[i].longitude,
      );
      if (distance < nearest) nearest = distance;
    }
    return nearest;
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return radius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = _rad(from.latitude);
    final lat2 = _rad(to.latitude);
    final dLon = _rad(to.longitude - from.longitude);
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  double _rad(double deg) => deg * pi / 180;

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _safeNotify({bool force = false}) {
    if (_disposed) return;
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastDashboardNotify) <
            const Duration(milliseconds: 80)) {
      return;
    }
    _lastDashboardNotify = now;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _positionSub?.cancel();
    _markerTimer?.cancel();
    super.dispose();
  }
}
