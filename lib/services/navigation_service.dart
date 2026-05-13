import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/route_models.dart';
import '../utils/formatters.dart';
import 'bluetooth_service.dart';

const String osrmBaseUrl = 'https://router.project-osrm.org';
const String navigationHttpUserAgent =
    'yezdiadv/1.0 (OpenStreetMap OSRM navigation)';

class NavService extends ChangeNotifier {
  Position? _currentPosition;
  List<RouteOption> _routeOptions = [];
  RouteOption? _activeRoute;
  int _selectedRouteIndex = 0;
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  bool _isLoadingRoute = false;
  bool _rerouteInProgress = false;
  bool _disposed = false;
  String _error = '';
  double _remainingDistanceMeters = 0;
  int _offRouteSamples = 0;
  int _routeRequestId = 0;

  StreamSubscription<Position>? _positionSub;
  DateTime _lastBleWrite = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRerouteAt = DateTime.fromMillisecondsSinceEpoch(0);
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

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _error = 'Location services are disabled';
        _safeNotify();
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _error = 'Location permission required';
        _safeNotify();
        return false;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _currentPosition = lastKnown;
        _safeNotify();
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      _safeNotify();
      return true;
    } catch (e) {
      _error = 'Location unavailable: $e';
      _safeNotify();
      return false;
    }
  }

  Future<void> fetchRoutes(
    LatLng destination, {
    String travelMode = 'driving',
  }) async {
    if (_currentPosition == null && !await initLocation()) return;

    final requestId = ++_routeRequestId;
    _isLoadingRoute = true;
    _error = '';
    if (!_isNavigating) {
      _routeOptions = [];
      _activeRoute = null;
      _remainingDistanceMeters = 0;
    }
    _safeNotify();

    final origin =
        '${_currentPosition!.longitude},${_currentPosition!.latitude}';
    final dest = '${destination.longitude},${destination.latitude}';
    final profile = _osrmProfile(travelMode);
    final url = Uri.parse('$osrmBaseUrl/route/v1/$profile/$origin;$dest')
        .replace(queryParameters: const {
      'alternatives': 'true',
      'steps': 'true',
      'overview': 'full',
      'geometries': 'geojson',
      'continue_straight': 'true',
    });

    try {
      final response = await _getWithRetry(url);
      if (_disposed || requestId != _routeRequestId) return;

      if (response.statusCode != 200) {
        _error = 'OSRM route error ${response.statusCode}';
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') {
        _error = 'No route found: ${data['code'] ?? 'unknown OSRM error'}';
        return;
      }

      final routes = data['routes'] as List? ?? const [];
      _routeOptions = routes
          .whereType<Map<String, dynamic>>()
          .map((route) => _parseOsrmRoute(
                route,
                destination,
                routes.indexOf(route),
              ))
          .where((route) => route.polyline.isNotEmpty)
          .toList();

      if (_routeOptions.isEmpty) {
        _error = 'OSRM returned an empty route';
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
        _safeNotify();
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
    _offRouteSamples = 0;
    if (notify) _safeNotify();
  }

  void startNavigation(BikeBluetoothService btService) {
    if (_activeRoute == null || _isNavigating) return;
    _isNavigating = true;
    _currentStepIndex = 0;
    _lastSignal = null;
    _lastDtmBucket = null;
    _offRouteSamples = 0;
    btService.sendStartNavigation();

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(
      (pos) => _onLocationUpdate(pos, btService),
      onError: (Object error) {
        _error = 'Location update failed: $error';
        _safeNotify();
      },
      cancelOnError: false,
    );
    _safeNotify();
  }

  void stopNavigation({BikeBluetoothService? btService}) {
    if (!_isNavigating && _positionSub == null) return;
    _isNavigating = false;
    _positionSub?.cancel();
    _positionSub = null;
    _offRouteSamples = 0;
    btService?.sendStopNavigation();
    _safeNotify();
  }

  void _onLocationUpdate(Position pos, BikeBluetoothService btService) {
    _currentPosition = pos;
    final route = _activeRoute;
    if (route == null || route.steps.isEmpty) {
      _safeNotify();
      return;
    }

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

    while (distToStep < 22 && _currentStepIndex < route.steps.length - 1) {
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
    if (finalDistance < 25) {
      _remainingDistanceMeters = 0;
      btService.sendArrival();
      stopNavigation();
      _safeNotify();
      return;
    }

    var remaining = distToStep;
    for (var i = _currentStepIndex + 1; i < route.steps.length; i++) {
      remaining += route.steps[i].distanceMeters;
    }
    _remainingDistanceMeters = remaining;

    _sendBleStep(btService, step, distToStep.round(), remaining);
    _maybeReroute(pos);
    _safeNotify();
  }

  void _maybeReroute(Position pos) {
    final route = _activeRoute;
    if (!_isNavigating ||
        _rerouteInProgress ||
        route == null ||
        route.polyline.length < 2) {
      return;
    }

    final offRouteDistance = _nearestRoutePointDistance(pos, route.polyline);
    _offRouteSamples = offRouteDistance > 85 ? _offRouteSamples + 1 : 0;
    final canReroute =
        DateTime.now().difference(_lastRerouteAt) > const Duration(seconds: 25);

    if (_offRouteSamples < 3 || !canReroute) return;

    _rerouteInProgress = true;
    _lastRerouteAt = DateTime.now();
    fetchRoutes(route.destination).whenComplete(() {
      _rerouteInProgress = false;
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
    final signal = _maneuverToYezdiSignal(step);
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

  int _maneuverToYezdiSignal(NavStep step) {
    final type = step.maneuverType.toLowerCase();
    final modifier = step.modifier.toLowerCase();
    final text = '${step.maneuver} ${step.instruction}'.toLowerCase();

    if (type == 'depart') return 100;
    if (type == 'arrive' || text.contains('destination')) return 36;

    if (type == 'roundabout' || type == 'rotary') {
      return _roundaboutSignal(step.exitNumber);
    }

    if (type == 'roundabout turn') {
      return _modifierSignal(modifier);
    }

    if (modifier.contains('uturn') || text.contains('u-turn')) return 17;
    if (modifier == 'sharp right') return 7;
    if (modifier == 'sharp left') return 21;

    if (type == 'fork' ||
        type == 'merge' ||
        type == 'on ramp' ||
        type == 'off ramp' ||
        type == 'ramp') {
      if (modifier.contains('left')) return 13;
      if (modifier.contains('right')) return 9;
    }

    return _modifierSignal(modifier);
  }

  int _modifierSignal(String modifier) {
    if (modifier == 'sharp right') return 7;
    if (modifier == 'sharp left') return 21;
    if (modifier == 'slight right') return 9;
    if (modifier == 'slight left') return 13;
    if (modifier == 'right') return 3;
    if (modifier == 'left') return 5;
    if (modifier == 'uturn') return 17;
    return 1;
  }

  int _roundaboutSignal(int? exitNumber) {
    if (exitNumber == null) return 39;
    if (exitNumber >= 7) return 24;
    return switch (exitNumber) {
      1 => 19,
      2 => 25,
      3 => 27,
      4 => 29,
      5 => 28,
      6 => 26,
      _ => 39,
    };
  }

  RouteOption _parseOsrmRoute(
    Map<String, dynamic> route,
    LatLng destination,
    int index,
  ) {
    final polyline = _parseGeoJsonLine(route['geometry']);
    final legs = route['legs'] as List? ?? const [];
    final leg = legs.isEmpty
        ? <String, dynamic>{}
        : (legs.first as Map).cast<String, dynamic>();
    final rawSteps = (leg['steps'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final steps = <NavStep>[];

    for (var i = 0; i < rawSteps.length; i++) {
      final rawStep = rawSteps[i];
      final maneuver =
          (rawStep['maneuver'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      final nextManeuver = i + 1 < rawSteps.length
          ? (rawSteps[i + 1]['maneuver'] as Map?)?.cast<String, dynamic>()
          : null;
      final stepGeometry = _parseGeoJsonLine(rawStep['geometry']);
      final startLocation = _latLngFromLonLat(maneuver['location']) ??
          (stepGeometry.isNotEmpty
              ? stepGeometry.first
              : polyline.isNotEmpty
                  ? polyline.first
                  : destination);
      final endLocation = _latLngFromLonLat(nextManeuver?['location']) ??
          (stepGeometry.isNotEmpty
              ? stepGeometry.last
              : polyline.isNotEmpty
                  ? polyline.last
                  : destination);
      final type = maneuver['type']?.toString() ?? 'continue';
      final modifier = maneuver['modifier']?.toString() ?? 'straight';
      final exitNumber = (maneuver['exit'] as num?)?.round();
      final roadName = rawStep['name']?.toString() ?? '';

      steps.add(
        NavStep(
          instruction: _buildInstruction(type, modifier, roadName, exitNumber),
          maneuver: '$type $modifier'.trim(),
          maneuverType: type,
          modifier: modifier,
          exitNumber: exitNumber,
          roadName: roadName,
          distanceMeters: (rawStep['distance'] as num? ?? 0).round(),
          durationSeconds: (rawStep['duration'] as num? ?? 0).round(),
          startLocation: startLocation,
          endLocation: endLocation,
        ),
      );
    }

    final summary = (leg['summary'] as String? ?? '').trim();
    return RouteOption(
      summary: summary.isEmpty ? _fallbackRouteSummary(index) : summary,
      distanceMeters: (route['distance'] as num? ?? 0).round(),
      durationSeconds: (route['duration'] as num? ?? 0).round(),
      polyline: polyline,
      steps: steps,
      destination: destination,
    );
  }

  String _buildInstruction(
    String type,
    String modifier,
    String roadName,
    int? exitNumber,
  ) {
    final direction = modifier == 'straight' ? 'straight' : modifier;
    final suffix = roadName.trim().isEmpty ? '' : ' onto ${roadName.trim()}';

    return switch (type) {
      'depart' => 'Start riding $direction$suffix',
      'arrive' => 'Arrive at destination',
      'turn' => 'Turn $direction$suffix',
      'new name' => 'Continue$suffix',
      'continue' => 'Continue $direction$suffix',
      'merge' => 'Merge $direction$suffix',
      'on ramp' || 'off ramp' || 'ramp' => 'Take the ramp $direction$suffix',
      'fork' => 'Keep $direction at the fork$suffix',
      'end of road' => 'At the end of the road, turn $direction$suffix',
      'use lane' => 'Use the $direction lane$suffix',
      'roundabout' || 'rotary' =>
        'At the roundabout, take ${_ordinal(exitNumber)} exit$suffix',
      'roundabout turn' => 'At the roundabout, turn $direction$suffix',
      _ => 'Continue $direction$suffix',
    };
  }

  String _ordinal(int? number) {
    if (number == null || number <= 0) return 'the';
    final teen = number % 100 >= 11 && number % 100 <= 13;
    final suffix = teen
        ? 'th'
        : switch (number % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$number$suffix';
  }

  String _fallbackRouteSummary(int index) {
    if (index == 0) return 'Fastest OSRM route';
    return 'Alternative ${index + 1}';
  }

  List<LatLng> _parseGeoJsonLine(dynamic geometry) {
    if (geometry is! Map) return const [];
    final coordinates = geometry['coordinates'];
    if (coordinates is! List) return const [];

    return coordinates
        .map(_latLngFromLonLat)
        .whereType<LatLng>()
        .toList(growable: false);
  }

  LatLng? _latLngFromLonLat(dynamic coordinates) {
    if (coordinates is! List || coordinates.length < 2) return null;
    final lon = (coordinates[0] as num?)?.toDouble();
    final lat = (coordinates[1] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.get(uri, headers: _headers).timeout(
              const Duration(seconds: 14),
            );
        if (response.statusCode < 500 || attempt == 1) return response;
      } catch (e) {
        lastError = e;
      }

      await Future.delayed(Duration(milliseconds: 350 * (attempt + 1)));
    }

    throw lastError ?? StateError('OSRM request failed');
  }

  Map<String, String> get _headers => const {
        'Accept': 'application/json',
        'User-Agent': navigationHttpUserAgent,
        'Accept-Language': 'en-IN,en;q=0.9',
      };

  String _osrmProfile(String travelMode) {
    return switch (travelMode.toLowerCase()) {
      'walking' || 'foot' => 'foot',
      'cycling' || 'bicycling' || 'bike' => 'bike',
      _ => 'driving',
    };
  }

  double _nearestRoutePointDistance(Position pos, List<LatLng> routePoints) {
    var nearest = double.infinity;
    for (final point in routePoints) {
      final distance = _distanceMeters(
        pos.latitude,
        pos.longitude,
        point.latitude,
        point.longitude,
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

  double _rad(double deg) => deg * pi / 180;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _positionSub?.cancel();
    super.dispose();
  }
}
