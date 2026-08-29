import 'dart:ui';

import 'package:flutter/material.dart';

/// 毛玻璃卡片：对背后内容做模糊 + 半透明底色。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.blur = 12,
    this.opacity = 0.55,
    this.radius = 16,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double blur;
  final double opacity;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06)
                .withValues(alpha: opacity * 0.2 + 0.08),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 带图标的分区标题（事件 / AI 总结 板块标题）。
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
