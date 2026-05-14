import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/google_maps_config.dart';
import '../models/route_models.dart';

class PlacesService {
  final Map<String, LatLng> _locationCache = {};
  String _sessionToken = _newSessionToken();

  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? location,
  }) async {
    final query = input.trim();
    if (query.length < 2) return [];
    if (!hasGoogleMapsApiKey) {
      debugPrint('Places autocomplete skipped: Google Maps API key missing');
      return [];
    }

    final params = <String, String>{
      'input': query,
      'key': googleMapsApiKey,
      'components': 'country:in',
      'language': 'en',
      'sessiontoken': _sessionToken,
    };

    if (location != null) {
      params['location'] = '${location.latitude},${location.longitude}';
      params['radius'] = '50000';
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      params,
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        debugPrint(
          'Places autocomplete failed: ${data['status']} ${data['error_message'] ?? ''}',
        );
        return [];
      }

      final predictions = data['predictions'] as List? ?? const [];
      return predictions
          .whereType<Map<String, dynamic>>()
          .map(PlacePrediction.fromAutocompleteJson)
          .where((p) => p.placeId.isNotEmpty)
          .toList();
    } catch (_) {
      debugPrint('Places autocomplete request failed');
      return [];
    }
  }

  Future<LatLng?> placeLatLng(String placeId) async {
    if (placeId.isEmpty || !hasGoogleMapsApiKey) return _locationCache[placeId];
    if (_locationCache.containsKey(placeId)) return _locationCache[placeId];

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'geometry',
        'key': googleMapsApiKey,
        'sessiontoken': _sessionToken,
      },
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        debugPrint(
          'Place details failed: ${data['status']} ${data['error_message'] ?? ''}',
        );
        return null;
      }
      final location = data['result']?['geometry']?['location'];
      if (location is! Map) return null;

      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final latLng = LatLng(lat, lng);
      _locationCache[placeId] = latLng;
      _sessionToken = _newSessionToken();
      return latLng;
    } catch (_) {
      debugPrint('Place details request failed');
      return null;
    }
  }

  static String _newSessionToken() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
