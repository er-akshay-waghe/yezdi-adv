import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlacePrediction {
  final String description;
  final String placeId;

  const PlacePrediction({
    required this.description,
    required this.placeId,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      description: json['description'] as String? ?? '',
      placeId: json['place_id'] as String? ?? '',
    );
  }
}

class RouteOption {
  final String summary;
  final int distanceMeters;
  final int durationSeconds;
  final List<LatLng> polyline;
  final List<NavStep> steps;
  final LatLng destination;

  const RouteOption({
    required this.summary,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
    required this.steps,
    required this.destination,
  });
}

class NavStep {
  final String instruction;
  final String maneuver;
  final int distanceMeters;
  final LatLng startLocation;
  final LatLng endLocation;

  const NavStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.startLocation,
    required this.endLocation,
  });
}
