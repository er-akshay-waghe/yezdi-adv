import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/app_theme.dart';

class RouteMapOverlay {
  final List<LatLng> points;
  final Color color;
  final int width;

  const RouteMapOverlay({
    required this.points,
    required this.color,
    this.width = 7,
  });
}

class GoogleDashboardMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final double bearing;
  final double tilt;
  final List<RouteMapOverlay> routes;
  final LatLng? currentLocation;
  final LatLng? destination;
  final ValueChanged<GoogleMapController>? onMapCreated;
  final ValueChanged<LatLng>? onTap;
  final VoidCallback? onCameraMoveStarted;
  final CameraPositionCallback? onCameraMove;
  final VoidCallback? onCameraIdle;
  final bool showTraffic;
  final bool myLocationEnabled;
  final bool interactive;

  const GoogleDashboardMap({
    super.key,
    required this.center,
    required this.zoom,
    this.bearing = 0,
    this.tilt = 0,
    this.routes = const [],
    this.currentLocation,
    this.destination,
    this.onMapCreated,
    this.onTap,
    this.onCameraMoveStarted,
    this.onCameraMove,
    this.onCameraIdle,
    this.showTraffic = false,
    this.myLocationEnabled = false,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: center,
        zoom: zoom,
        bearing: bearing,
        tilt: tilt,
      ),
      onMapCreated: (controller) {
        controller.setMapStyle(googleDarkMapStyle);
        onMapCreated?.call(controller);
      },
      onTap: onTap,
      onCameraMoveStarted: onCameraMoveStarted,
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
      mapType: MapType.normal,
      trafficEnabled: showTraffic,
      buildingsEnabled: true,
      compassEnabled: false,
      rotateGesturesEnabled: interactive,
      scrollGesturesEnabled: interactive,
      tiltGesturesEnabled: interactive,
      zoomGesturesEnabled: interactive,
      zoomControlsEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(3, 20),
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      gestureRecognizers: interactive
          ? {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            }
          : const <Factory<OneSequenceGestureRecognizer>>{},
      polylines: {
        for (var i = 0; i < routes.length; i++)
          if (routes[i].points.length > 1)
            Polyline(
              polylineId: PolylineId('route_$i'),
              points: routes[i].points,
              color: routes[i].color,
              width: routes[i].width,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              geodesic: false,
            ),
      },
      markers: {
        if (destination != null)
          Marker(
            markerId: const MarkerId('destination'),
            position: destination!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        if (currentLocation != null)
          Marker(
            markerId: const MarkerId('rider'),
            position: currentLocation!,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            rotation: bearing,
            zIndex: 10,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
      },
    );
  }
}

class MapZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const MapZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom in',
            onPressed: onZoomIn,
            icon: const Icon(Icons.add, color: AppColors.text),
          ),
          Container(
            width: 28,
            height: 1,
            color: AppColors.border,
          ),
          IconButton(
            tooltip: 'Zoom out',
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

const String googleDarkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#10151d"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8e99a8"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#07090d"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#202936"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#0a0d12"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#a6afbb"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#253343"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#ffb33b"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#071018"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3ea2ff"}]}
]
''';

class MapGlassScrim extends StatelessWidget {
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const MapGlassScrim({
    super.key,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: const [
              Color(0xD907090D),
              Color(0x3307090D),
              Color(0xD907090D),
            ],
          ),
        ),
      ),
    );
  }
}

class GpsQualityDot extends StatelessWidget {
  final double accuracyMeters;

  const GpsQualityDot({super.key, required this.accuracyMeters});

  @override
  Widget build(BuildContext context) {
    final color = accuracyMeters <= 12
        ? AppColors.green
        : accuracyMeters <= 30
            ? AppColors.yellow
            : AppColors.red;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
