import 'package:latlong2/latlong.dart';

class PlacePrediction {
  final String description;
  final String placeId;
  final LatLng? location;

  const PlacePrediction({
    required this.description,
    required this.placeId,
    this.location,
  });

  factory PlacePrediction.fromNominatimJson(Map<String, dynamic> json) {
    final osmType = json['osm_type']?.toString() ?? 'place';
    final osmId = json['osm_id']?.toString() ?? '';
    final lat = double.tryParse(json['lat']?.toString() ?? '');
    final lng = double.tryParse(json['lon']?.toString() ?? '');

    return PlacePrediction(
      description: json['display_name'] as String? ?? 'Unnamed place',
      placeId: '$osmType:$osmId',
      location: lat == null || lng == null ? null : LatLng(lat, lng),
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
  final String maneuverType;
  final String modifier;
  final int? exitNumber;
  final String roadName;
  final int distanceMeters;
  final int durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;

  const NavStep({
    required this.instruction,
    required this.maneuver,
    required this.maneuverType,
    required this.modifier,
    required this.exitNumber,
    required this.roadName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
  });
}
