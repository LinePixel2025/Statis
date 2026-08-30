import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/events_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_summary_provider.dart';
import '../ui/add_event_dialog.dart';
import '../ui/ai_summary_card.dart';
import '../ui/event_card.dart';
import '../ui/github_style.dart';
import '../ui/glass_card.dart';
import '../ui/settings_dialog.dart';

/// 顶栏内容高度。
const double _kBarHeight = 60;

/// 主界面：GitHub 风格顶栏（白底 + 底部 1px 分隔线，悬浮）+ 两板块（事件 / AI 总结）。
class MainWindow extends StatelessWidget {
  const MainWindow({super.key});

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventsProvider>();
    final ai = context.watch<AiSummaryProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
            fit: StackFit.expand,
            children: [
              // ---- 内容列表 ----
              ListView(
                padding: const EdgeInsets.fromLTRB(24, _kBarHeight + 14, 24, 32),
                children: [
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
                    GlassCard(
                      child: Builder(builder: (context) => Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text('正在生成全局总结…',
                              style: TextStyle(
                                  color: GithubStyle.textMuted)),
                        ],
                      )),
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
      // 添加事件浮动按钮
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddEventDialog(context, events),
        icon: const Icon(Icons.add),
        label: const Text('添加事件'),
      ),
    );
  }
}

/// 顶栏：Statis 字样 + 设置按钮 + 窗口控制（整条可拖拽移动窗口）。
/// GitHub 风格：白底 + 底部 1px 边框，深色标题，窗口按钮悬停浅灰。
class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: _kBarHeight,
      decoration: const BoxDecoration(
        color: GithubStyle.surface,
        border: Border(
          bottom: BorderSide(color: GithubStyle.border, width: 1),
        ),
      ),
      child: DragToMoveArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 8, 0),
          child: Row(
            children: [
              Text(
                'Statis',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  fontFamily: 'Microsoft YaHei',
                  fontFamilyFallback: const ['微软雅黑', 'Segoe UI'],
                  color: GithubStyle.text,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '设置',
                color: GithubStyle.textMuted,
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
    );
  }
}

/// 顶栏窗口控制按钮（最小化/最大化/关闭），深色图标 + 悬停浅灰背景。
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
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(GithubStyle.radius),
        hoverColor: GithubStyle.canvasHover,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 20,
            color: danger ? GithubStyle.danger : GithubStyle.textMuted,
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
      child: Column(
        children: [
          Icon(icon, size: 32, color: GithubStyle.textMuted),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: GithubStyle.textMuted),
          ),
        ],
      ),
    );
  }
}
