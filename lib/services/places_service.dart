import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/route_models.dart';
import 'navigation_service.dart';

class PlacesService {
  Future<List<PlacePrediction>> autocomplete(String input,
      {LatLng? location}) async {
    if (input.trim().length < 2 ||
        googleMapsApiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
      return [];
    }
    final locationBias = location == null
        ? ''
        : '&location=${location.latitude},${location.longitude}&radius=50000';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeQueryComponent(input)}&key=$googleMapsApiKey&components=country:in$locationBias',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final predictions = data['predictions'] as List? ?? [];
    return predictions
        .map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<LatLng?> placeLatLng(String placeId) async {
    if (placeId.isEmpty || googleMapsApiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
      return null;
    }
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId&fields=geometry&key=$googleMapsApiKey',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final loc = data['result']?['geometry']?['location'];
    if (loc == null) {
      return null;
    }
    return LatLng(
        (loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
  }
}
