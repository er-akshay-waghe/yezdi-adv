import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/route_models.dart';
import '../services/navigation_service.dart';
import '../services/places_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/glass_card.dart';
import '../widgets/osm_map_view.dart';
import 'navigation_screen.dart';

class RouteSelectionScreen extends StatefulWidget {
  const RouteSelectionScreen({super.key});

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  final _destinationController = TextEditingController();
  final _places = PlacesService();
  final _sourceController = TextEditingController(text: 'Current location');
  final _mapController = MapController();
  Timer? _debounce;
  List<PlacePrediction> _predictions = [];
  bool _loadingPlace = false;
  bool _mapReady = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _destinationController.dispose();
    _sourceController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavService>();
    final pos = nav.currentPosition;
    final initialTarget = pos == null
        ? const LatLng(12.9716, 77.5946)
        : LatLng(pos.latitude, pos.longitude);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: YezdiOsmMap(
              mapController: _mapController,
              center: initialTarget,
              zoom: 13,
              currentLocation:
                  pos == null ? null : LatLng(pos.latitude, pos.longitude),
              destination: nav.activeRoute?.destination,
              onMapReady: () {
                _mapReady = true;
                final activeRoute = nav.activeRoute;
                if (activeRoute != null) _fitRoute(activeRoute.polyline);
              },
              routes: [
                for (var i = 0; i < nav.routeOptions.length; i++)
                  RouteMapOverlay(
                    points: nav.routeOptions[i].polyline,
                    strokeWidth: i == nav.selectedRouteIndex ? 7 : 4,
                    borderStrokeWidth: i == nav.selectedRouteIndex ? 4 : 2,
                    color: i == nav.selectedRouteIndex
                        ? AppColors.green
                        : AppColors.blue.withValues(alpha: .45),
                  ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0xF207090D), Color(0x0007090D)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _SearchPanel(
                  sourceController: _sourceController,
                  destinationController: _destinationController,
                  predictions: _predictions,
                  loading: _loadingPlace || nav.isLoadingRoute,
                  error: nav.error,
                  onBack: () => Navigator.pop(context),
                  onDestinationChanged: _onDestinationChanged,
                  onPredictionTap: _selectPrediction,
                ),
                const Spacer(),
                if (nav.routeOptions.isNotEmpty)
                  _RouteOptionsSheet(
                    routes: nav.routeOptions,
                    selectedIndex: nav.selectedRouteIndex,
                    onSelect: (index) {
                      nav.selectRoute(index);
                      _fitRoute(nav.routeOptions[index].polyline);
                    },
                    onStart: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const NavigationScreen()),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onDestinationChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final nav = context.read<NavService>();
      final pos = nav.currentPosition;
      final near = pos == null ? null : LatLng(pos.latitude, pos.longitude);
      final predictions = await _places.autocomplete(value, location: near);
      if (mounted) setState(() => _predictions = predictions);
    });
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loadingPlace = true;
      _predictions = [];
      _destinationController.text = prediction.description;
    });
    final target =
        prediction.location ?? await _places.placeLatLng(prediction.placeId);
    if (target != null && mounted) {
      final nav = context.read<NavService>();
      await nav.fetchRoutes(target);
      if (!mounted) return;
      if (nav.activeRoute != null) _fitRoute(nav.activeRoute!.polyline);
    }
    if (mounted) setState(() => _loadingPlace = false);
  }

  void _fitRoute(List<LatLng> points) {
    if (points.length < 2 || !_mapReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(70, 150, 70, 260),
          maxZoom: 16,
        ),
      );
    });
  }
}

class _SearchPanel extends StatelessWidget {
  final TextEditingController sourceController;
  final TextEditingController destinationController;
  final List<PlacePrediction> predictions;
  final bool loading;
  final String error;
  final VoidCallback onBack;
  final ValueChanged<String> onDestinationChanged;
  final ValueChanged<PlacePrediction> onPredictionTap;

  const _SearchPanel({
    required this.sourceController,
    required this.destinationController,
    required this.predictions,
    required this.loading,
    required this.error,
    required this.onBack,
    required this.onDestinationChanged,
    required this.onPredictionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                    onPressed: onBack, icon: const Icon(Icons.arrow_back)),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text('Plan route',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                if (loading)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: sourceController,
              readOnly: true,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.my_location), labelText: 'Source'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: destinationController,
              onChanged: onDestinationChanged,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), labelText: 'Destination'),
            ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(error,
                    style: const TextStyle(color: AppColors.red, fontSize: 12)),
              ),
            if (predictions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...predictions.take(5).map(
                    (prediction) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.place, color: AppColors.green),
                      title: Text(prediction.description,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => onPredictionTap(prediction),
                    ),
                  ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 250.ms).slideY(begin: -.04, end: 0),
    );
  }
}

class _RouteOptionsSheet extends StatelessWidget {
  final List<RouteOption> routes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;

  const _RouteOptionsSheet({
    required this.routes,
    required this.selectedIndex,
    required this.onSelect,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final selected = routes[selectedIndex];
    return Padding(
      padding: const EdgeInsets.all(14),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 102,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: routes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final route = routes[index];
                  final selected = index == selectedIndex;
                  return GestureDetector(
                    onTap: () => onSelect(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 170,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.green.withValues(alpha: .16)
                            : AppColors.surfaceHigh.withValues(alpha: .75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                selected ? AppColors.green : AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              route.summary.isEmpty
                                  ? 'Fastest route'
                                  : route.summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text(formatDuration(route.durationSeconds),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w900)),
                          Text(formatDistance(route.distanceMeters),
                              style: const TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatDuration(selected.durationSeconds),
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w900)),
                      Text(
                          '${formatDistance(selected.distanceMeters)} via ${selected.summary.isEmpty ? 'selected route' : selected.summary}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Start'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: .08, end: 0),
    );
  }
}
