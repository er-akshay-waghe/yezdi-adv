import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

class StatusActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const StatusActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.16),
            border: Border.all(color: color.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 22,
                spreadRadius: color == AppColors.green ? 1 : 0,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 21),
        ),
      ),
    );
  }
}
