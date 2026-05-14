import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../utils/app_theme.dart';

class AdventureBackdrop extends StatelessWidget {
  final Widget child;

  const AdventureBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.nightGradient,
              ),
            ),
          ),
        ),
        const Positioned.fill(child: _TopoGrid()),
        child,
      ],
    );
  }
}

class PremiumPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry borderRadius;
  final Color? borderColor;
  final Color? glowColor;

  const PremiumPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.borderColor,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? AppColors.orange.withValues(alpha: 0.12);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: glow,
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor ?? AppColors.border,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GradientActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool expanded;

  const GradientActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.adventureGradient),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: .36),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.background),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class GlowIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  const GlowIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color = AppColors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: .13),
            border: Border.all(color: color.withValues(alpha: .48)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .22),
                blurRadius: 22,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 21),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(18, 20, 18, 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class PremiumNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final IconData fallbackIcon;

  const PremiumNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.terrain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _ImagePlaceholder().animate(onPlay: (c) => c.repeat()).shimmer(
              duration: 1200.ms,
              color: Colors.white12,
            );
      },
      errorBuilder: (_, __, ___) => _ImagePlaceholder(icon: fallbackIcon),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final IconData icon;

  const _ImagePlaceholder({this.icon = Icons.terrain});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surfaceHigh, Color(0xFF2A1B12)],
        ),
      ),
      child: Center(
        child: Icon(icon, color: AppColors.amber, size: 34),
      ),
    );
  }
}

class _TopoGrid extends StatelessWidget {
  const _TopoGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TopoPainter(), size: Size.infinite);
  }
}

class _TopoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final line = Paint()
      ..color = AppColors.amber.withValues(alpha: .045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < 13; i++) {
      final y = size.height * (0.06 + i * .085);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 42) {
        path.lineTo(x, y + 14 * (i.isEven ? 1 : -1) * (x / size.width));
      }
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
