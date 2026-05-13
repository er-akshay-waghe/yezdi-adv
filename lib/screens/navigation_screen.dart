import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/route_models.dart';
import '../services/bluetooth_service.dart';
import '../services/navigation_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/glass_card.dart';
import '../widgets/nav_arrow_widget.dart';
import '../widgets/osm_map_view.dart';
import '../widgets/status_action_button.dart';
import 'home_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _mapController = MapController();
  late final BikeBluetoothService _btService;
  late final NavService _navService;
  bool _followUser = true;
  bool _mapReady = false;
  bool _stopped = false;
  DateTime _lastCameraMove = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _btService = context.read<BikeBluetoothService>();
    _navService = context.read<NavService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navService.startNavigation(_btService);
    });
  }

  @override
  void dispose() {
    if (!_stopped) {
      _navService.stopNavigation(btService: _btService);
    }
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavService>();
    final bt = context.watch<BikeBluetoothService>();
    final pos = nav.currentPosition;
    if (_followUser && pos != null) {
      _moveToCurrent(pos.latitude, pos.longitude);
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: pos == null
                ? Container(
                    color: AppColors.background,
                    child: const Center(child: CircularProgressIndicator()),
                  )
                : YezdiOsmMap(
                    mapController: _mapController,
                    center: LatLng(pos.latitude, pos.longitude),
                    zoom: 17,
                    currentLocation: LatLng(pos.latitude, pos.longitude),
                    destination: nav.activeRoute?.destination,
                    onMapReady: () => _mapReady = true,
                    onPositionChanged: (_, hasGesture) {
                      if (hasGesture && _followUser && mounted) {
                        setState(() => _followUser = false);
                      }
                    },
                    routes: [
                      RouteMapOverlay(
                        points: nav.polylinePoints,
                        color: AppColors.green,
                        strokeWidth: 7,
                        borderStrokeWidth: 4,
                      ),
                    ],
                  ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xD907090D),
                  Color(0x0007090D),
                  Color(0xD907090D)
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _NavTopBar(bt: bt, nav: nav, onStop: _stopAndExit),
                const Spacer(),
                _TurnPanel(nav: nav, bt: bt)
                    .animate()
                    .fadeIn(duration: 250.ms)
                    .slideY(begin: .08, end: 0),
              ],
            ),
          ),
          if (!_followUser && pos != null)
            Positioned(
              right: 18,
              bottom: 210,
              child: FloatingActionButton.small(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.green,
                onPressed: () {
                  _mapController.move(
                    LatLng(pos.latitude, pos.longitude),
                    17,
                  );
                  setState(() => _followUser = true);
                },
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),
    );
  }

  void _stopAndExit() {
    _stopped = true;
    _navService.stopNavigation(btService: _btService);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  void _moveToCurrent(double latitude, double longitude) {
    if (!_mapReady) return;
    final now = DateTime.now();
    if (now.difference(_lastCameraMove) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastCameraMove = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady || !_followUser) return;
      _mapController.move(LatLng(latitude, longitude), 17);
    });
  }
}

class _NavTopBar extends StatelessWidget {
  final BikeBluetoothService bt;
  final NavService nav;
  final VoidCallback onStop;

  const _NavTopBar({required this.bt, required this.nav, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            StatusActionButton(
              icon:
                  bt.isConnected ? Icons.two_wheeler : Icons.bluetooth_disabled,
              color: bt.isConnected ? AppColors.green : AppColors.red,
              tooltip: bt.isConnected
                  ? 'Sending to bike display'
                  : 'Bike display offline',
              onTap: bt.isConnected ? null : bt.enableAutoConnect,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatDistance(nav.remainingDistanceMeters),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 18)),
                  const Text('remaining',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Stop navigation',
              onPressed: onStop,
              icon: const Icon(Icons.close, color: AppColors.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnPanel extends StatelessWidget {
  final NavService nav;
  final BikeBluetoothService bt;

  const _TurnPanel({required this.nav, required this.bt});

  @override
  Widget build(BuildContext context) {
    final step = nav.currentStep;
    if (step == null) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: GlassCard(child: Text('Preparing route')),
      );
    }

    final direction = _directionForStep(step);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: BorderRadius.circular(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.green.withValues(alpha: .13),
                    border: Border.all(
                        color: AppColors.green.withValues(alpha: .36)),
                  ),
                  child: Center(
                      child: NavArrowWidget(
                          direction: direction,
                          size: 62,
                          color: AppColors.green)),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatDistance(nav.distanceToNextStep),
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              height: 1)),
                      const SizedBox(height: 8),
                      Text(step.instruction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                              bt.isConnected
                                  ? Icons.check_circle
                                  : Icons.sync_problem,
                              color: bt.isConnected
                                  ? AppColors.green
                                  : AppColors.yellow,
                              size: 16),
                          const SizedBox(width: 6),
                          Text(
                            bt.isConnected
                                ? 'Live on cluster'
                                : 'Phone navigation only',
                            style: TextStyle(
                                color: bt.isConnected
                                    ? AppColors.green
                                    : AppColors.yellow,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (nav.currentStepIndex + 1 < nav.steps.length) ...[
              const SizedBox(height: 16),
              _NextStep(step: nav.steps[nav.currentStepIndex + 1]),
            ],
          ],
        ),
      ),
    );
  }

  NavDirection _directionForStep(NavStep step) {
    final type = step.maneuverType.toLowerCase();
    final modifier = step.modifier.toLowerCase();
    final text = step.instruction.toLowerCase();
    if (type == 'arrive' || text.contains('destination')) {
      return NavDirection.arrive;
    }
    if (type.contains('roundabout') || type == 'rotary') {
      return NavDirection.roundabout;
    }
    if (modifier.contains('uturn') || text.contains('u-turn')) {
      return NavDirection.uTurn;
    }
    if (modifier.contains('left') || text.contains(' left')) {
      return NavDirection.left;
    }
    if (modifier.contains('right') || text.contains(' right')) {
      return NavDirection.right;
    }
    return NavDirection.straight;
  }
}

class _NextStep extends StatelessWidget {
  final NavStep step;

  const _NextStep({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Text('Then',
              style: TextStyle(
                  color: AppColors.muted, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(step.instruction,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(formatDistance(step.distanceMeters),
              style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
