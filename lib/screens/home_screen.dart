import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../services/bluetooth_service.dart';
import '../services/navigation_service.dart';
import '../utils/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_action_button.dart';
import 'profile_screen.dart';
import 'route_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BikeBluetoothService>();
    final nav = context.watch<NavService>();
    final profile = context.watch<ProfileProvider>().profile;

    return Scaffold(
      body: Stack(
        children: [
          const _DashboardBackdrop(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _TopBar(bt: bt)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name.isEmpty
                              ? 'Ready to ride'
                              : 'Ready, ${profile.name.split(' ').first}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bt.status,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _SearchLauncher(nav: nav)),
                SliverToBoxAdapter(child: _MapPreview(nav: nav)),
                SliverToBoxAdapter(
                    child:
                        _BikeStatusCard(bt: bt, bikeModel: profile.bikeModel)),
                const SliverToBoxAdapter(child: _RideStatsGrid()),
                SliverToBoxAdapter(child: _RecentBleLog(logs: bt.txLog)),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final BikeBluetoothService bt;

  const _TopBar({required this.bt});

  @override
  Widget build(BuildContext context) {
    final bluetoothColor = !bt.isBluetoothOn
        ? AppColors.red
        : bt.isScanning
            ? AppColors.green
            : AppColors.blue;
    final bikeColor = switch (bt.connectionState) {
      BikeConnectionState.connected => AppColors.green,
      BikeConnectionState.connecting => AppColors.yellow,
      BikeConnectionState.disconnected => AppColors.muted,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'YEZDI ADV',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
            ),
          ),
          StatusActionButton(
            icon: bt.isBluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
            color: bluetoothColor,
            tooltip:
                bt.isScanning ? 'Scanning for MY YEZDI' : 'Bluetooth status',
            onTap: bt.isScanning
                ? bt.stopScan
                : () => bt.startScan(autoConnect: true),
          ),
          const SizedBox(width: 10),
          StatusActionButton(
            icon: bt.isConnected ? Icons.two_wheeler : Icons.motorcycle,
            color: bikeColor,
            tooltip:
                bt.isConnected ? 'MY YEZDI connected' : 'Connect to MY YEZDI',
            onTap: bt.isConnected ? bt.disconnect : bt.enableAutoConnect,
          ),
          const SizedBox(width: 10),
          StatusActionButton(
            icon: Icons.person,
            color: AppColors.blue,
            tooltip: 'Rider profile',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  final NavService nav;

  const _SearchLauncher({required this.nav});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RouteSelectionScreen())),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.green),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Search destination',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.35)),
                ),
                child: const Text('Navigate',
                    style: TextStyle(
                        color: AppColors.green, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: .08, end: 0),
    );
  }
}

class _MapPreview extends StatelessWidget {
  final NavService nav;

  const _MapPreview({required this.nav});

  @override
  Widget build(BuildContext context) {
    final pos = nav.currentPosition;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SizedBox(
        height: 260,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (pos == null)
                Container(
                  color: AppColors.surface,
                  child: const Center(child: CircularProgressIndicator()),
                )
              else
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(pos.latitude, pos.longitude),
                    zoom: 15,
                    tilt: 35,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  trafficEnabled: true,
                ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location,
                          color: AppColors.blue, size: 19),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pos == null
                              ? 'Locating rider'
                              : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 450.ms).scale(begin: const Offset(.98, .98)),
    );
  }
}

class _BikeStatusCard extends StatelessWidget {
  final BikeBluetoothService bt;
  final String bikeModel;

  const _BikeStatusCard({required this.bt, required this.bikeModel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: bt.isConnected
                      ? [
                          AppColors.green.withValues(alpha: .95),
                          AppColors.blue.withValues(alpha: .65)
                        ]
                      : [AppColors.surfaceHigh, AppColors.surface],
                ),
              ),
              child:
                  const Icon(Icons.two_wheeler, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bikeModel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(
                    bt.isConnected
                        ? 'MY YEZDI display online'
                        : 'Waiting for MY YEZDI',
                    style: TextStyle(
                        color:
                            bt.isConnected ? AppColors.green : AppColors.muted),
                  ),
                ],
              ),
            ),
            Icon(bt.isConnected ? Icons.verified : Icons.sync,
                color: bt.isConnected ? AppColors.green : AppColors.yellow),
          ],
        ),
      ),
    );
  }
}

class _RideStatsGrid extends StatelessWidget {
  const _RideStatsGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: const Row(
        children: [
          Expanded(
              child: _StatCard(
                  icon: Icons.route, label: 'Today', value: '0.0 km')),
          SizedBox(width: 12),
          Expanded(
              child: _StatCard(
                  icon: Icons.timer, label: 'Ride time', value: '0 min')),
          SizedBox(width: 12),
          Expanded(
              child: _StatCard(
                  icon: Icons.speed, label: 'Avg speed', value: '--')),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.blue, size: 20),
          const SizedBox(height: 12),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RecentBleLog extends StatelessWidget {
  final List<String> logs;

  const _RecentBleLog({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cluster packets',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...logs.take(3).map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(log,
                        style: const TextStyle(
                            color: AppColors.green,
                            fontFamily: 'monospace',
                            fontSize: 11)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071018), Color(0xFF07090D), Color(0xFF101316)],
        ),
      ),
      child: CustomPaint(painter: _RoadLinePainter(), size: Size.infinite),
    );
  }
}

class _RoadLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.green.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 8; i++) {
      final y = size.height * (0.16 + i * 0.12);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 80), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
