import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/events_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_summary_provider.dart';
import '../ui/add_event_dialog.dart';
import '../ui/ai_summary_card.dart';
import '../ui/event_card.dart';
import '../ui/glass_card.dart';
import '../ui/settings_dialog.dart';

/// 顶栏内容高度与渐变模糊遮罩向下延伸的高度。
const double _kBarHeight = 60;
const double _kBlurHeight = 96;

/// 主界面：顶栏悬浮（渐变模糊遮罩，滚动内容在其下柔和隐没）+ 两板块（事件 / AI 总结）。
class MainWindow extends StatelessWidget {
  const MainWindow({super.key});

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventsProvider>();
    final ai = context.watch<AiSummaryProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // ---- 内容列表：滚动时从顶栏下方经过，被渐变模糊柔和遮挡 ----
              ListView(
                padding: const EdgeInsets.fromLTRB(24, _kBarHeight + 14, 24, 32),
                children: [
                  // 板块一：事件
                  SectionHeader(icon: Icons.event_repeat, title: '事件'),
                  const SizedBox(height: 12),
                  ...events.events.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: EventCard(event: e, events: events, ai: ai),
                    ),
                  ),
                  if (events.events.isEmpty)
                    _EmptyHint(
                      icon: Icons.flag_outlined,
                      text: '还没有事件，点击右下角 + 添加一件会重复做的事情吧',
                    ),
                  const SizedBox(height: 20),
                  // 板块二：AI 总结
                  SectionHeader(icon: Icons.auto_awesome, title: 'AI 总结'),
                  const SizedBox(height: 12),
                  if (ai.generatingGlobal)
                    const GlassCard(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('正在生成全局总结…'),
                        ],
                      ),
                    )
                  else if (ai.globalSummary != null)
                    AiSummaryCard(
                      title: '全局总结',
                      text: ai.globalSummary!,
                      trailing: IconButton(
                        tooltip: '重新生成',
                        onPressed: ai.generating ? null : ai.generateGlobal,
                        icon: const Icon(Icons.refresh, size: 18),
                      ),
                    )
                  else
                    _EmptyHint(
                      icon: Icons.auto_awesome_outlined,
                      text: ai.error != null
                          ? '生成失败：${ai.error}'
                          : '开启 AI 并配置 API Key 后，这里会显示所有事件的简略总结',
                    ),
                ],
              ),
              // ---- 顶栏悬浮层 ----
              const Positioned(top: 0, left: 0, right: 0, child: _TitleBar()),
            ],
          ),
        ),
      ),
      // 添加事件浮动按钮
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddEventDialog(context, events),
        icon: const Icon(Icons.add),
        label: const Text('添加事件'),
      ),
    );
  }
}

/// 顶栏：Statis 字样 + 设置按钮 + 窗口控制（整条可拖拽移动窗口），
/// 背景为向下淡出的渐变模糊遮罩，替代原先的硬边分隔线。
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = foregroundOnBackdrop(context);
    return SizedBox(
      height: _kBarHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 渐变模糊层：顶部模糊+轻着色最强，向下淡出至透明（不拦截指针）。
          Positioned(
            top: 0,
            left: -24,
            right: -24,
            height: _kBlurHeight,
            child: IgnorePointer(
              child: ClipRect(
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF000000),
                      Color(0xD9000000),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      color: theme.colorScheme.surface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          DragToMoveArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 8, 0),
              child: Row(
                children: [
                  Text(
                    'Statis',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      fontFamily: 'Microsoft YaHei',
                      fontFamilyFallback: const ['微软雅黑', 'Segoe UI'],
                      color: fg,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '设置',
                    color: fg,
                    onPressed: () => showSettingsDialog(
                        context, context.read<SettingsProvider>()),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  // 自绘窗口控制按钮（系统标题栏已隐藏）。
                  _WindowButton(
                      icon: Icons.remove,
                      tooltip: '最小化',
                      onTap: () => windowManager.minimize()),
                  _WindowButton(
                      icon: Icons.crop_square,
                      tooltip: '最大化/还原',
                      onTap: () async {
                        if (await windowManager.isMaximized()) {
                          await windowManager.unmaximize();
                        } else {
                          await windowManager.maximize();
                        }
                      }),
                  _WindowButton(
                      icon: Icons.close,
                      tooltip: '关闭',
                      danger: true,
                      onTap: () => windowManager.close()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶栏窗口控制按钮（最小化/最大化/关闭），前景色随背景亮度自动反色。
class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = foregroundOnBackdrop(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 20,
            color: danger ? fg.withValues(alpha: 0.7) : fg,
          ),
        ),
      ),
    );
  }
}

/// 空状态提示卡片。
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      opacity: 0.3,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
