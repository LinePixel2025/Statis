import 'dart:ui';

import 'package:flutter/material.dart';

/// 感知亮度（0~1，Rec.601 加权），用于毛玻璃组件判断文字是否需要反色。
double perceivedLuminance(Color c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;

/// 暗面板上使用的浅色前景与次级前景。
const Color kLightForeground = Color(0xFFF3F4F8);
const Color kLightForegroundVariant = Color(0xFFC6C9D3);

/// 向子树提供窗口背景层的感知亮度，供毛玻璃组件自适应文字颜色。
class BackdropInfo extends InheritedWidget {
  const BackdropInfo({super.key, required this.luminance, required super.child});

  final double luminance;
  bool get isDark => luminance < 0.5;

  static BackdropInfo? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackdropInfo>();

  @override
  bool updateShouldNotify(BackdropInfo old) => old.luminance != luminance;
}

/// 直接落在窗口背景（非玻璃面板）上的文字/图标前景色，按背景亮度自动反色。
Color foregroundOnBackdrop(BuildContext context) {
  final info = BackdropInfo.of(context);
  return (info?.isDark ?? false)
      ? kLightForeground
      : Theme.of(context).colorScheme.onSurface;
}

/// 落在“surface 着色层”（如顶栏渐变模糊带）上的前景色：
/// 实际底色 = surface*tintOpacity + 背景*(1-tintOpacity)，按混合后的亮度反色。
Color foregroundOnTintedBackdrop(BuildContext context, {required double tintOpacity}) {
  final scheme = Theme.of(context).colorScheme;
  final bgLum = BackdropInfo.of(context)?.luminance ?? 1.0;
  final lum = perceivedLuminance(scheme.surface) * tintOpacity + bgLum * (1 - tintOpacity);
  return lum < 0.55 ? kLightForeground : scheme.onSurface;
}

/// 毛玻璃卡片：对背后内容做模糊，surface 以较低透明度铺底，透出背景质感；
/// 面板实际亮度偏暗时，内部文字/图标自动反色保证可读。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.blur = 18,
    this.opacity = 0.58,
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
    final scheme = theme.colorScheme;
    final bgLum = BackdropInfo.of(context)?.luminance ?? 1.0;
    // 面板亮度 = surface*透明度 + 背景*(1-透明度)。
    final panelLum =
        perceivedLuminance(scheme.surface) * opacity + bgLum * (1 - opacity);
    final darkPanel = panelLum < 0.55;
    final adjusted = darkPanel
        ? scheme.copyWith(
            onSurface: kLightForeground,
            onSurfaceVariant: kLightForegroundVariant,
            // 主色过暗时在深面板上提亮，保证图标/链接可见。
            primary: perceivedLuminance(scheme.primary) < 0.45
                ? Color.lerp(scheme.primary, Colors.white, 0.55)!
                : scheme.primary,
          )
        : scheme;
    final radius_ = BorderRadius.circular(radius);

    return ClipRRect(
      borderRadius: radius_,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius_,
            // 玻璃质感：surface 半透明铺底 + 顶部一层微弱高光渐变。
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surface.withValues(alpha: opacity + 0.10),
                scheme.surface.withValues(alpha: opacity),
                scheme.surface.withValues(alpha: opacity - 0.06),
              ],
            ),
            border: Border.all(
              color: adjusted.onSurface
                  .withValues(alpha: darkPanel ? 0.16 : 0.10),
            ),
          ),
          // Theme 覆盖只作用于 child 子树：卡片内容需在 Builder 内重新取主题，
          // 反色才会真正落到文字/图标样式上。
          child: Theme(data: theme.copyWith(colorScheme: adjusted), child: child),
        ),
      ),
    );
  }
}

/// 带图标的分区标题（事件 / AI 总结 板块标题），直接落在背景上，文字自适应反色。
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
                fontWeight: FontWeight.w700,
                color: foregroundOnBackdrop(context))),
      ],
    );
  }
}
