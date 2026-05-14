import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../utils/app_theme.dart';
import '../widgets/premium_components.dart';

class RidePlan {
  final String title;
  final String destination;
  final String date;
  final String difficulty;
  final int riders;
  final String imageUrl;
  final String description;
  final List<String> timeline;

  const RidePlan({
    required this.title,
    required this.destination,
    required this.date,
    required this.difficulty,
    required this.riders,
    required this.imageUrl,
    required this.description,
    required this.timeline,
  });
}

const _rides = [
  RidePlan(
    title: 'Western Ghats Trail',
    destination: 'Sakleshpur Ridge',
    date: '28 Jun 2026',
    difficulty: 'Moderate',
    riders: 18,
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
    description:
        'A dawn-to-dusk touring route through misty estate roads, gravel edges, and fast-flowing hill sections built for adventure riders.',
    timeline: ['05:30 meetup', '07:10 breakfast halt', '10:45 ridge trail', '16:30 return briefing'],
  ),
  RidePlan(
    title: 'Desert Night Run',
    destination: 'Little Rann',
    date: '17 Jul 2026',
    difficulty: 'Hard',
    riders: 11,
    imageUrl:
        'https://images.unsplash.com/photo-1509316785289-025f5b846b35?auto=format&fit=crop&w=1200&q=80',
    description:
        'A focused endurance ride across open salt flats and compact dirt, tuned for riders who like wide horizons and quiet engines.',
    timeline: ['15:00 vehicle check', '18:20 sunset entry', '21:10 camp halt', '06:00 exit route'],
  ),
  RidePlan(
    title: 'Coastal Gravel Loop',
    destination: 'Konkan Backroads',
    date: '09 Aug 2026',
    difficulty: 'Easy',
    riders: 24,
    imageUrl:
        'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1200&q=80',
    description:
        'A relaxed group ride along coastal lanes, broken tarmac, ferry crossings, and short gravel connectors.',
    timeline: ['06:00 roll out', '09:00 coast stop', '12:30 ferry crossing', '17:00 finish'],
  ),
];

class UpcomingRidesScreen extends StatelessWidget {
  const UpcomingRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdventureBackdrop(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            const SectionTitle(
              title: 'Upcoming Rides',
              subtitle: 'Curated adventure plans for the Yezdi community',
            ),
            ..._rides.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    child: _RideCard(ride: entry.value, index: entry.key),
                  ).animate().fadeIn(delay: (80 * entry.key).ms).slideY(
                        begin: .08,
                        end: 0,
                      ),
                ),
          ],
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final RidePlan ride;
  final int index;

  const _RideCard({required this.ride, required this.index});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RideDetailScreen(ride: ride, index: index)),
      ),
      child: PremiumPanel(
        padding: EdgeInsets.zero,
        borderColor: AppColors.orange.withValues(alpha: .32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'ride_image_$index',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                child: AspectRatio(
                  aspectRatio: 16 / 8,
                  child: PremiumNetworkImage(imageUrl: ride.imageUrl),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ride.title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(ride.destination, style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _RideChip(icon: Icons.calendar_month, label: ride.date),
                      _RideChip(icon: Icons.groups, label: '${ride.riders} riders'),
                      _RideChip(icon: Icons.terrain, label: ride.difficulty),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RideDetailScreen extends StatelessWidget {
  final RidePlan ride;
  final int index;

  const RideDetailScreen({super.key, required this.ride, required this.index});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AdventureBackdrop(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              title: Text(ride.title),
              backgroundColor: AppColors.background,
              flexibleSpace: FlexibleSpaceBar(
                background: Hero(
                  tag: 'ride_image_$index',
                  child: PremiumNetworkImage(imageUrl: ride.imageUrl),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ride.destination, style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(ride.description, style: const TextStyle(color: AppColors.muted, height: 1.45)),
                        const SizedBox(height: 20),
                        PremiumPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ride Timeline', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 14),
                              for (final item in ride.timeline)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.radio_button_checked, color: AppColors.amber, size: 16),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(item)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        PremiumPanel(
                          child: Row(
                            children: [
                              const Icon(Icons.route, color: AppColors.blue, size: 34),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Route Preview', style: TextStyle(fontWeight: FontWeight.w900)),
                                    SizedBox(height: 4),
                                    Text('Google route preview slot ready for upcoming ride GPX/KML overlays.', style: TextStyle(color: AppColors.muted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        PremiumPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Participants', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  for (var i = 0; i < 5; i++)
                                    Align(
                                      widthFactor: .72,
                                      child: CircleAvatar(
                                        backgroundColor: i.isEven ? AppColors.orange : AppColors.blue,
                                        child: Text('${i + 1}', style: const TextStyle(color: AppColors.background)),
                                      ),
                                    ),
                                  const SizedBox(width: 18),
                                  Text('${ride.riders} riders registered', style: const TextStyle(color: AppColors.muted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RideChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RideChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.amber),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
