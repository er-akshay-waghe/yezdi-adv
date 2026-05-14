import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../utils/app_theme.dart';
import '../widgets/premium_components.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AdventureBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
            children: [
              Row(
                children: [
                  GlowIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 12),
                  Text('Help', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 20),
              PremiumPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2A1B12), AppColors.surfaceHigh],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.play_circle_fill, color: AppColors.amber, size: 64),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('YouTube Guide Placeholder', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                          SizedBox(height: 6),
                          Text('Future setup, pairing, and route planning videos can be embedded here.', style: TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: .05, end: 0),
              const SizedBox(height: 18),
              const _FaqItem(
                question: 'Why is search not showing suggestions?',
                answer: 'Enable Places API, Directions API, Maps SDK for Android, billing, and key restrictions for this app.',
              ),
              const _FaqItem(
                question: 'How do I connect the bike display?',
                answer: 'Keep Bluetooth and location enabled. My Yezdi auto-scans for MY YEZDI and reconnects after drops.',
              ),
              const _FaqItem(
                question: 'Can navigation continue in the background?',
                answer: 'The app includes foreground navigation service scaffolding for active ride sessions.',
              ),
              const SizedBox(height: 18),
              GradientActionButton(
                icon: Icons.support_agent,
                label: 'Contact support',
                expanded: true,
                onPressed: null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumPanel(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            iconColor: AppColors.amber,
            collapsedIconColor: AppColors.muted,
            title: Text(question, style: const TextStyle(fontWeight: FontWeight.w900)),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(answer, style: const TextStyle(color: AppColors.muted, height: 1.45)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
