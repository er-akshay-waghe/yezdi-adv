import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../utils/app_theme.dart';
import '../widgets/premium_components.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2300), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: const HomeScreen(),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AdventureBackdrop(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.adventureGradient,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange.withValues(alpha: .42),
                        blurRadius: 42,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.two_wheeler,
                    size: 70,
                    color: AppColors.background,
                  ),
                )
                    .animate()
                    .scale(duration: 650.ms, curve: Curves.easeOutBack)
                    .fadeIn(),
                const SizedBox(height: 28),
                Text(
                  'My Yezdi',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                        letterSpacing: 0,
                        shadows: [
                          Shadow(
                            color: AppColors.amber.withValues(alpha: .55),
                            blurRadius: 22,
                          ),
                        ],
                      ),
                )
                    .animate()
                    .fadeIn(delay: 250.ms, duration: 600.ms)
                    .slideY(begin: .1, end: 0),
                const SizedBox(height: 10),
                const Text(
                  'Adventure navigation command center',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().fadeIn(delay: 520.ms),
                const SizedBox(height: 44),
                SizedBox(
                  width: 168,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceHigh,
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(
                      duration: 1200.ms,
                      color: AppColors.orange.withValues(alpha: .35),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
