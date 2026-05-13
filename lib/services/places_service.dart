import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/route_models.dart';

const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
const String yezdiHttpUserAgent =
    'yezdiadv/1.0 (OpenStreetMap Flutter navigation)';

class PlacesService {
  final Map<String, LatLng> _locationCache = {};

  Future<List<PlacePrediction>> autocomplete(
    String input, {
    LatLng? location,
  }) async {
    final query = input.trim();
    if (query.length < 2) return [];

    final params = <String, String>{
      'format': 'jsonv2',
      'q': query,
      'limit': '6',
      'addressdetails': '0',
      'dedupe': '1',
      'countrycodes': 'in',
    };

    if (location != null) {
      params.addAll(_viewBoxParams(location));
    }

    final uri =
        Uri.parse('$nominatimBaseUrl/search').replace(queryParameters: params);

    try {
      final response = await http.get(uri, headers: _headers).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode != 200) return [];

      final raw = jsonDecode(response.body);
      if (raw is! List) return [];

      final predictions = raw
          .whereType<Map<String, dynamic>>()
          .map(PlacePrediction.fromNominatimJson)
          .where((p) => p.location != null)
          .toList();

      for (final prediction in predictions) {
        _locationCache[prediction.placeId] = prediction.location!;
      }

      return predictions;
    } catch (_) {
      return [];
    }
  }

  Future<LatLng?> placeLatLng(String placeId) async {
    return _locationCache[placeId];
  }

  Map<String, String> get _headers => const {
        'Accept': 'application/json',
        'User-Agent': yezdiHttpUserAgent,
        'Accept-Language': 'en-IN,en;q=0.9',
      };

  Map<String, String> _viewBoxParams(LatLng center) {
    const delta = 0.6;
    final left = center.longitude - delta;
    final right = center.longitude + delta;
    final top = center.latitude + delta;
    final bottom = center.latitude - delta;

    return {
      'viewbox': '$left,$top,$right,$bottom',
      'bounded': '0',
    };
  }
}
