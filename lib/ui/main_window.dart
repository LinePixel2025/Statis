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

/// 主界面：顶部 Statis 标题 + 设置按钮 + 自绘窗口控制按钮；下方两板块（事件 / AI 总结）。
class MainWindow extends StatelessWidget {
  const MainWindow({super.key});

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventsProvider>();
    final ai = context.watch<AiSummaryProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              // ---- 顶栏：Statis 字样 + 设置按钮 + 窗口控制（可拖拽移动窗口）----
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 0, 4),
                child: Row(
                  children: [
                    Text(
                      'statis',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '设置',
                      onPressed: () =>
                          showSettingsDialog(context, context.read<SettingsProvider>()),
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
              DragToMoveArea(
                child: Divider(
                    height: 1,
                    indent: 24,
                    endIndent: 24,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
              ),
              // ---- 两板块 ----
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
              ),
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

/// 顶栏窗口控制按钮（最小化/最大化/关闭）。
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
    final theme = Theme.of(context);
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
            color: danger ? theme.colorScheme.onSurfaceVariant : null,
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
