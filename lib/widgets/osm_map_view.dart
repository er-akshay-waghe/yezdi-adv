import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../utils/app_theme.dart';

const String yezdiTileUserAgentPackage = 'com.example.yezdiadv';
const String yezdiOsmTileUrl =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

class RouteMapOverlay {
  final List<LatLng> points;
  final Color color;
  final double strokeWidth;
  final double borderStrokeWidth;

  const RouteMapOverlay({
    required this.points,
    required this.color,
    this.strokeWidth = 6,
    this.borderStrokeWidth = 3,
  });
}

class YezdiOsmMap extends StatelessWidget {
  final MapController? mapController;
  final LatLng center;
  final double zoom;
  final List<RouteMapOverlay> routes;
  final LatLng? currentLocation;
  final LatLng? destination;
  final TapCallback? onTap;
  final PositionCallback? onPositionChanged;
  final VoidCallback? onMapReady;
  final bool interactive;
  final bool showAttribution;
  final bool darkMode;

  const YezdiOsmMap({
    super.key,
    this.mapController,
    required this.center,
    required this.zoom,
    this.routes = const [],
    this.currentLocation,
    this.destination,
    this.onTap,
    this.onPositionChanged,
    this.onMapReady,
    this.interactive = true,
    this.showAttribution = true,
    this.darkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 3,
        maxZoom: 19,
        onTap: onTap,
        onPositionChanged: onPositionChanged,
        onMapReady: onMapReady,
        interactionOptions: interactive
            ? const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              )
            : const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        TileLayer(
          urlTemplate: yezdiOsmTileUrl,
          userAgentPackageName: yezdiTileUserAgentPackage,
          maxNativeZoom: 19,
          tileBuilder: darkMode ? darkModeTileBuilder : null,
        ),
        if (routes.any((route) => route.points.length > 1))
          PolylineLayer(
            polylines: [
              for (final route in routes.where((r) => r.points.length > 1))
                Polyline(
                  points: route.points,
                  color: route.color,
                  strokeWidth: route.strokeWidth,
                  borderColor: Colors.black.withValues(alpha: 0.42),
                  borderStrokeWidth: route.borderStrokeWidth,
                ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (destination != null)
              Marker(
                point: destination!,
                width: 42,
                height: 42,
                child: const _DestinationMarker(),
              ),
            if (currentLocation != null)
              Marker(
                point: currentLocation!,
                width: 46,
                height: 46,
                child: const _CurrentLocationMarker(),
              ),
          ],
        ),
        if (showAttribution)
          RichAttributionWidget(
            alignment: AttributionAlignment.bottomRight,
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                prependCopyright: true,
              ),
            ],
          ),
      ],
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.blue.withValues(alpha: 0.22),
          border: Border.all(color: AppColors.blue, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(alpha: 0.38),
              blurRadius: 18,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.blue,
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.location_on,
      color: AppColors.red,
      size: 40,
      shadows: [
        Shadow(color: Colors.black87, blurRadius: 10),
      ],
    );
  }
}
