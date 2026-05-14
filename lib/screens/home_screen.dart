import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../services/bluetooth_service.dart';
import '../services/dashboard_status_service.dart';
import '../services/navigation_service.dart';
import '../utils/app_theme.dart';
import '../widgets/google_dashboard_map.dart';
import '../widgets/premium_components.dart';
import 'credits_screen.dart';
import 'feedback_screen.dart';
import 'gallery_screen.dart';
import 'help_screen.dart';
import 'profile_screen.dart';
import 'route_selection_screen.dart';
import 'upcoming_rides_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _DashboardTab(),
      const UpcomingRidesScreen(),
      const GalleryScreen(),
      const _MenuTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: NavigationBar(
              height: 72,
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dash'),
                NavigationDestination(icon: Icon(Icons.terrain), label: 'Rides'),
                NavigationDestination(icon: Icon(Icons.photo_library), label: 'Gallery'),
                NavigationDestination(icon: Icon(Icons.grid_view), label: 'Menu'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BikeBluetoothService>();
    final nav = context.watch<NavService>();
    final status = context.watch<DashboardStatusService>();
    final profile = context.watch<ProfileProvider>().profile;

    return AdventureBackdrop(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _TopCommandBar(
                bt: bt,
                status: status,
                riderName: profile.name,
              ),
            ),
            SliverToBoxAdapter(child: _HeroCommand(nav: nav, bt: bt)),
            SliverToBoxAdapter(child: _LiveMapPreview(nav: nav)),
            SliverToBoxAdapter(child: _BikeStatusPanel(bt: bt, status: status)),
            SliverToBoxAdapter(child: _AdventureStats(nav: nav, status: status)),
            SliverToBoxAdapter(child: _QuickActions(bt: bt)),
            SliverToBoxAdapter(child: _ClusterPackets(logs: bt.txLog)),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

class _TopCommandBar extends StatelessWidget {
  final BikeBluetoothService bt;
  final DashboardStatusService status;
  final String riderName;

  const _TopCommandBar({
    required this.bt,
    required this.status,
    required this.riderName,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = riderName.trim().isEmpty ? 'Rider' : riderName.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Yezdi',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: AppColors.orange.withValues(alpha: .32),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Ready, $firstName',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          GlowIconButton(
            icon: Icons.notifications,
            tooltip: 'Notifications',
            color: status.latestAlert == null ? AppColors.amber : AppColors.orange,
          ),
          const SizedBox(width: 10),
          GlowIconButton(
            icon: Icons.settings,
            tooltip: 'Profile',
            color: AppColors.blue,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCommand extends StatelessWidget {
  final NavService nav;
  final BikeBluetoothService bt;

  const _HeroCommand({required this.nav, required this.bt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: PremiumPanel(
        padding: const EdgeInsets.all(20),
        borderColor: AppColors.orange.withValues(alpha: .38),
        glowColor: AppColors.orange.withValues(alpha: .18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: AppColors.adventureGradient),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange.withValues(alpha: .34),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.explore, color: AppColors.background, size: 34),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Adventure Command', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        bt.status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GradientActionButton(
              icon: Icons.navigation,
              label: 'Plan new route',
              expanded: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RouteSelectionScreen()),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: .06, end: 0),
    );
  }
}

class _LiveMapPreview extends StatelessWidget {
  final NavService nav;

  const _LiveMapPreview({required this.nav});

  @override
  Widget build(BuildContext context) {
    final pos = nav.currentPosition;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: SizedBox(
        height: 240,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (pos == null)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.surfaceHigh, AppColors.surface]),
                  ),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                GoogleDashboardMap(
                  center: LatLng(pos.latitude, pos.longitude),
                  zoom: 15,
                  currentLocation: LatLng(pos.latitude, pos.longitude),
                  bearing: nav.bearing,
                  interactive: false,
                  showTraffic: false,
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: PremiumPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, color: AppColors.blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pos == null
                              ? 'Acquiring rider location'
                              : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: 120.ms).scale(begin: const Offset(.98, .98)),
    );
  }
}

class _BikeStatusPanel extends StatelessWidget {
  final BikeBluetoothService bt;
  final DashboardStatusService status;

  const _BikeStatusPanel({required this.bt, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: PremiumPanel(
        child: Row(
          children: [
            _StatusHalo(
              icon: bt.isConnected ? Icons.two_wheeler : Icons.bluetooth_disabled,
              color: bt.isConnected ? AppColors.green : AppColors.orange,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bt.isConnected ? 'MY YEZDI cluster online' : 'Cluster standby',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  Text(bt.status, style: const TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
            _NetworkBars(bars: status.networkBars, online: status.isOnline),
          ],
        ),
      ),
    );
  }
}

class _AdventureStats extends StatelessWidget {
  final NavService nav;
  final DashboardStatusService status;

  const _AdventureStats({required this.nav, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Row(
        children: [
          Expanded(child: _StatTile(icon: Icons.speed, label: 'Speed', value: '${nav.speedKmh.round()}')),
          const SizedBox(width: 12),
          Expanded(child: _StatTile(icon: Icons.explore, label: 'Heading', value: '${status.heading.round()}°')),
          const SizedBox(width: 12),
          Expanded(child: _StatTile(icon: Icons.battery_5_bar, label: 'Battery', value: '${status.batteryLevel}%')),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final BikeBluetoothService bt;

  const _QuickActions({required this.bt});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Quick Controls', padding: EdgeInsets.fromLTRB(18, 22, 18, 10)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.bluetooth_searching,
                  label: bt.isConnected ? 'Disconnect' : 'Connect',
                  onTap: bt.isConnected ? bt.disconnect : bt.enableAutoConnect,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: Icons.terrain,
                  label: 'Rides',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UpcomingRidesScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: Icons.support_agent,
                  label: 'Help',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpScreen()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClusterPackets extends StatelessWidget {
  final List<String> logs;

  const _ClusterPackets({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: PremiumPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cluster Sync', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...logs.take(3).map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      log,
                      style: const TextStyle(
                        color: AppColors.amber,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _MenuTab extends StatelessWidget {
  const _MenuTab();

  @override
  Widget build(BuildContext context) {
    final items = [
      _MenuItem(Icons.terrain, 'Upcoming Rides', 'Plan community adventures', const UpcomingRidesScreen()),
      _MenuItem(Icons.photo_library, 'Photos Gallery', 'Ride memories and trail shots', const GalleryScreen()),
      _MenuItem(Icons.feedback, 'Feedback', 'Bugs, ideas, and reviews', const FeedbackScreen()),
      _MenuItem(Icons.workspace_premium, 'Credits', 'Creators and project story', const CreditsScreen()),
      _MenuItem(Icons.help_center, 'Help', 'Video guides and FAQs', const HelpScreen()),
      _MenuItem(Icons.person, 'Profile', 'Rider and bike details', const ProfileScreen()),
    ];

    return AdventureBackdrop(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            const SectionTitle(
              title: 'Command Menu',
              subtitle: 'Tools, support, and ride community',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GridView.builder(
                itemCount: items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .95,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _MenuCard(item: item)
                      .animate()
                      .fadeIn(delay: (60 * index).ms)
                      .slideY(begin: .05, end: 0);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  const _MenuItem(this.icon, this.title, this.subtitle, this.page);
}

class _MenuCard extends StatelessWidget {
  final _MenuItem item;

  const _MenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.page)),
      child: PremiumPanel(
        glowColor: AppColors.blue.withValues(alpha: .08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusHalo(icon: item.icon, color: AppColors.amber, size: 46),
            const Spacer(),
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              item.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: PremiumPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: AppColors.amber),
            const SizedBox(height: 10),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.blue, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusHalo extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _StatusHalo({required this.icon, required this.color, this.size = 58});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .13),
        border: Border.all(color: color.withValues(alpha: .42)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .2), blurRadius: 24),
        ],
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _NetworkBars extends StatelessWidget {
  final int bars;
  final bool online;

  const _NetworkBars({required this.bars, required this.online});

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
                  : AppColors.muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}
