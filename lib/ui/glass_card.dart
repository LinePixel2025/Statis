import 'package:flutter/material.dart';

import 'github_style.dart';

/// GitHub 风格扁平卡片：白底 + 1px 边框 + 6 圆角 + 轻微阴影。
/// 提供 padding / radius / borderColor / surface 可选参数以兼容既有调用。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.opacity = 0.58,
    this.blur = 18,
    this.radius = GithubStyle.radius,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;

  // 以下参数为兼容旧调用而保留。GitHub 扁平风格下 blur / opacity 不再生效，
  // 但保留字段避免改动所有调用点；如未来需要可控透明度可在此扩展。
  final double opacity;
  final double blur;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = GithubStyle.surface;
    final radius_ = BorderRadius.circular(radius);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: radius_,
        border: Border.all(color: GithubStyle.border),
        // 轻微下沉阴影，GitHub 卡片常见处理。
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2328).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 带图标的分区标题（事件 / AI 总结 板块标题），落在 GitHub 画布上，固定深色文字。
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700, color: GithubStyle.text)),
      ],
    );
  }
}
