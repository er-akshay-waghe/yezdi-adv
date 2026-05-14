import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/dashboard_status.dart';
import '../models/route_models.dart';
import '../services/background_navigation_service.dart';
import '../services/bluetooth_service.dart';
import '../services/dashboard_status_service.dart';
import '../services/navigation_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/glass_card.dart';
import '../widgets/google_dashboard_map.dart';
import '../widgets/nav_arrow_widget.dart';
import '../widgets/status_action_button.dart';
import 'home_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  late final BikeBluetoothService _btService;
  late final NavService _navService;
  bool _followUser = true;
  bool _stopped = false;
  bool _programmaticCameraMove = false;
  DateTime _lastCameraMove = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _lastCameraTarget;
  double _lastCameraBearing = 0;

  @override
  void initState() {
    super.initState();
    _btService = context.read<BikeBluetoothService>();
    _navService = context.read<NavService>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await BackgroundNavigationService.start();
      _navService.startNavigation(_btService);
    });
  }

  @override
  void dispose() {
    if (!_stopped) {
      _navService.stopNavigation(btService: _btService);
      BackgroundNavigationService.stop();
    }
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavService>();
    final bt = context.watch<BikeBluetoothService>();
    final status = context.watch<DashboardStatusService>();
    final fallbackLocation = nav.smoothedLocation;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<LatLng?>(
              valueListenable: nav.smoothedLocationNotifier,
              builder: (context, smoothLocation, _) {
                final location = smoothLocation ?? fallbackLocation;
                if (location == null) {
                  return Container(
                    color: AppColors.background,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                return ValueListenableBuilder<double>(
                  valueListenable: nav.bearingNotifier,
                  builder: (context, smoothBearing, _) {
                    final bearing =
                        smoothBearing == 0 ? nav.bearing : smoothBearing;
                    if (_followUser) {
                      _moveCamera(nav, location, bearing: bearing);
                    }

                    return GoogleDashboardMap(
                      center: location,
                      zoom: nav.cameraZoom,
                      bearing: bearing,
                      tilt: 52,
                      currentLocation: location,
                      destination: nav.activeRoute?.destination,
                      onMapCreated: (controller) => _mapController = controller,
                      onCameraMoveStarted: () {
                        if (!_programmaticCameraMove && _followUser && mounted) {
                          setState(() => _followUser = false);
                        }
                      },
                      onCameraIdle: () => _programmaticCameraMove = false,
                      routes: [
                        RouteMapOverlay(
                          points: nav.polylinePoints,
                          color: AppColors.amber,
                          width: 7,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const Positioned.fill(child: MapGlassScrim()),
          SafeArea(
            child: Column(
              children: [
                _NavTopBar(
                  bt: bt,
                  nav: nav,
                  status: status,
                  onStop: _stopAndExit,
                ),
                const Spacer(),
                _RoundDashboardPanel(nav: nav, bt: bt, status: status)
                    .animate()
                    .fadeIn(duration: 220.ms)
                    .slideY(begin: .04, end: 0),
              ],
            ),
          ),
          if (status.latestAlert != null)
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).padding.top + 82,
              child: _NotificationOverlay(
                alert: status.latestAlert!,
                onDismiss: status.clearLatestAlert,
              ),
            ),
          Positioned(
            right: 16,
            bottom: 220,
            child: Column(
              children: [
                MapZoomControls(
                  onZoomIn: () => _zoomBy(1),
                  onZoomOut: () => _zoomBy(-1),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'follow',
                  backgroundColor: AppColors.surface,
                  foregroundColor:
                      _followUser ? AppColors.amber : AppColors.muted,
                  onPressed: () {
                    setState(() => _followUser = !_followUser);
                    final loc = nav.smoothedLocation;
                    if (loc != null) _moveCamera(nav, loc, force: true);
                  },
                  child: const Icon(Icons.explore),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'notif_perm',
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.blue,
                  onPressed: status.requestNotificationAccess,
                  child: const Icon(Icons.notifications_active),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _stopAndExit() {
    _stopped = true;
    _navService.stopNavigation(btService: _btService);
    BackgroundNavigationService.stop();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  void _moveCamera(
    NavService nav,
    LatLng location, {
    bool force = false,
    double? bearing,
  }) {
    if (_mapController == null) return;
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastCameraMove) < const Duration(milliseconds: 580)) {
      return;
    }

    final nextBearing = bearing ?? nav.bearing;
    final lastTarget = _lastCameraTarget;
    if (!force && lastTarget != null) {
      final movedMeters = _distanceMeters(lastTarget, location);
      final bearingDelta = _angleDelta(_lastCameraBearing, nextBearing);
      if (movedMeters < 3.5 && bearingDelta < 6) return;
    }

    _lastCameraMove = now;
    _lastCameraTarget = location;
    _lastCameraBearing = nextBearing;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mapController == null || !_followUser) return;
      _programmaticCameraMove = true;
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: nav.cameraZoom,
            bearing: nextBearing,
            tilt: 52,
          ),
        ),
      ).whenComplete(() {
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          _programmaticCameraMove = false;
        });
      });
    });
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const radius = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    return radius * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  double _angleDelta(double from, double to) {
    return (((to - from + 540) % 360) - 180).abs();
  }

  double _rad(double degrees) => degrees * pi / 180;

  void _zoomBy(double amount) {
    final controller = _mapController;
    if (controller == null) return;
    _programmaticCameraMove = true;
    controller.animateCamera(CameraUpdate.zoomBy(amount)).whenComplete(() {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        _programmaticCameraMove = false;
      });
    });
  }
}

class _NavTopBar extends StatelessWidget {
  final BikeBluetoothService bt;
  final NavService nav;
  final DashboardStatusService status;
  final VoidCallback onStop;

  const _NavTopBar({
    required this.bt,
    required this.nav,
    required this.status,
    required this.onStop,
  });

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
            const SizedBox(width: 10),
            _SignalBars(bars: status.networkBars, online: status.isOnline),
            const SizedBox(width: 10),
            GpsQualityDot(accuracyMeters: nav.gpsAccuracyMeters),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nav.isRerouting
                    ? 'Recalculating route'
                    : '${formatDistance(nav.remainingDistanceMeters)}  ${formatDuration(nav.etaSeconds)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            _BatteryPill(level: status.batteryLevel),
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

class _RoundDashboardPanel extends StatelessWidget {
  final NavService nav;
  final BikeBluetoothService bt;
  final DashboardStatusService status;

  const _RoundDashboardPanel({
    required this.nav,
    required this.bt,
    required this.status,
  });

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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: RepaintBoundary(
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          borderRadius: BorderRadius.circular(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.amber.withValues(alpha: .12),
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: .45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amber.withValues(alpha: .22),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Center(
                      child: NavArrowWidget(
                        direction: direction,
                        size: 72,
                        color: AppColors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDistance(nav.distanceToNextStep),
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step.instruction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _MetricChip(
                              icon: Icons.speed,
                              text: '${nav.speedKmh.round()} km/h',
                            ),
                            _MetricChip(
                              icon: Icons.explore,
                              text: '${status.heading.round()}°',
                            ),
                            _MetricChip(
                              icon: bt.isConnected
                                  ? Icons.check_circle
                                  : Icons.sync_problem,
                              text: bt.isConnected
                                  ? 'Cluster live'
                                  : 'Phone only',
                              color: bt.isConnected
                                  ? AppColors.green
                                  : AppColors.yellow,
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
      ),
    );
  }

  NavDirection _directionForStep(NavStep step) {
    final m = step.maneuver.toLowerCase();
    final text = step.instruction.toLowerCase();
    if (m.contains('arrive') || text.contains('destination')) {
      return NavDirection.arrive;
    }
    if (m.contains('roundabout')) return NavDirection.roundabout;
    if (m.contains('uturn') || text.contains('u-turn')) {
      return NavDirection.uTurn;
    }
    if (m.contains('left') || text.contains(' left')) return NavDirection.left;
    if (m.contains('right') || text.contains(' right')) {
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
          const Text(
            'Then',
            style:
                TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.instruction,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            formatDistance(step.distanceMeters),
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.text,
    this.color = AppColors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final int bars;
  final bool online;

  const _SignalBars({required this.bars, required this.online});

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.green : AppColors.red;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 4; i++)
          Container(
            width: 5,
            height: 7.0 + i * 4,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: i <= bars && online
                  ? color
                  : AppColors.muted.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

class _BatteryPill extends StatelessWidget {
  final int level;

  const _BatteryPill({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = level > 35
        ? AppColors.green
        : level > 18
            ? AppColors.yellow
            : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(
        '$level%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _NotificationOverlay extends StatelessWidget {
  final DashboardAlert alert;
  final VoidCallback onDismiss;

  const _NotificationOverlay({
    required this.alert,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (alert.type) {
      DashboardAlertType.call => Icons.call,
      DashboardAlertType.sms => Icons.sms,
      DashboardAlertType.app => Icons.notifications,
      DashboardAlertType.system => Icons.info,
    };
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.circular(22),
      child: Row(
        children: [
          Icon(icon, color: AppColors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (alert.body.isNotEmpty)
                  Text(
                    alert.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 180.ms).slideY(begin: -.1, end: 0);
  }
}
