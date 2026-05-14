import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../utils/app_theme.dart';
import '../widgets/premium_components.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

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
                  Text('Credits', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 26),
              PremiumPanel(
                padding: const EdgeInsets.all(24),
                borderColor: AppColors.amber.withValues(alpha: .38),
                child: Column(
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: AppColors.adventureGradient),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orange.withValues(alpha: .36),
                            blurRadius: 34,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.two_wheeler, color: AppColors.background, size: 48),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'My Yezdi',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            shadows: [
                              Shadow(
                                color: AppColors.amber.withValues(alpha: .5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Premium adventure motorcycle navigation companion',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ).animate().fadeIn().scale(begin: const Offset(.96, .96)),
              const SizedBox(height: 18),
              const _DeveloperCard(name: 'Akshay Waghe', role: 'Product, app engineering, Yezdi cluster integration'),
              const SizedBox(height: 12),
              const _DeveloperCard(name: 'Prasad Pednekar', role: 'Experience design, testing, rider workflows'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  final String name;
  final String role;

  const _DeveloperCard({required this.name, required this.role});

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.orange.withValues(alpha: .2),
            child: Text(
              name.split(' ').map((part) => part[0]).take(2).join(),
              style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 4),
                Text(role, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: .05, end: 0);
  }
}
