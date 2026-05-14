import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../utils/app_theme.dart';
import '../widgets/premium_components.dart';

class GalleryPhoto {
  final String title;
  final String imageUrl;

  const GalleryPhoto({required this.title, required this.imageUrl});
}

const _photos = [
  GalleryPhoto(
    title: 'Trail sunrise',
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
  ),
  GalleryPhoto(
    title: 'High pass',
    imageUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=900&q=80',
  ),
  GalleryPhoto(
    title: 'Night bivouac',
    imageUrl:
        'https://images.unsplash.com/photo-1478131143081-80f7f84ca84d?auto=format&fit=crop&w=900&q=80',
  ),
  GalleryPhoto(
    title: 'Dust line',
    imageUrl:
        'https://images.unsplash.com/photo-1509316785289-025f5b846b35?auto=format&fit=crop&w=900&q=80',
  ),
  GalleryPhoto(
    title: 'Forest road',
    imageUrl:
        'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=900&q=80',
  ),
  GalleryPhoto(
    title: 'Coastal halt',
    imageUrl:
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80',
  ),
];

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdventureBackdrop(
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: SectionTitle(
                title: 'Ride Gallery',
                subtitle: 'Cinematic memories from trails, highways, and camps',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
              sliver: SliverGrid.builder(
                itemCount: _photos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .82,
                ),
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  return _PhotoTile(photo: photo, index: index)
                      .animate()
                      .fadeIn(delay: (60 * index).ms)
                      .scale(begin: const Offset(.96, .96));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final GalleryPhoto photo;
  final int index;

  const _PhotoTile({required this.photo, required this.index});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: PhotoPreviewScreen(photo: photo, index: index),
          ),
        ),
      ),
      child: PremiumPanel(
        padding: EdgeInsets.zero,
        borderColor: AppColors.blue.withValues(alpha: .26),
        glowColor: AppColors.blue.withValues(alpha: .1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'gallery_$index',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: PremiumNetworkImage(imageUrl: photo.imageUrl),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                photo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black, blurRadius: 12)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhotoPreviewScreen extends StatelessWidget {
  final GalleryPhoto photo;
  final int index;

  const PhotoPreviewScreen({super.key, required this.photo, required this.index});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Hero(
              tag: 'gallery_$index',
              child: PremiumNetworkImage(imageUrl: photo.imageUrl, fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .55),
                    Colors.transparent,
                    Colors.black.withValues(alpha: .75),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlowIconButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(photo.title, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Captured from the My Yezdi adventure archive',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
