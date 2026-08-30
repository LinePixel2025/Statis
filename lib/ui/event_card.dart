import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/events_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_summary_provider.dart';
import '../ui/heatmap.dart';
import '../ui/trend_line.dart';
import 'github_style.dart';
import 'glass_card.dart';

/// 主界面事件卡片：紧凑摘要行（名称、分类、统计、记录按钮、展开箭头）+ 可展开详情（热力图、AI 摘要、关键词、删除）。
class EventCard extends StatefulWidget {
  const EventCard({super.key, required this.event, required this.events, required this.ai});

  final Event event;
  final EventsProvider events;
  final AiSummaryProvider ai;

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  /// 详情区（热力图 / AI 摘要 / 关键词 / 删除）是否展开。
  bool _expanded = false;

  /// 折线图鼠标悬停的天数索引（-1 表示无悬停），用于 tooltip。
  int _hoverIndex = -1;

  Future<void> _openRecordDialog(BuildContext context) async {
    final noteCtl = TextEditingController();
    DateTime occurred = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('记录「${widget.event.name}」'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(
                    '${occurred.year}-${occurred.month.toString().padLeft(2, '0')}-${occurred.day.toString().padLeft(2, '0')} '
                    '${occurred.hour.toString().padLeft(2, '0')}:${occurred.minute.toString().padLeft(2, '0')}'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: occurred,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null || !ctx.mounted) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(occurred),
                  );
                  if (time == null) return;
                  setState(() {
                    occurred = DateTime(
                        date.year, date.month, date.day, time.hour, time.minute);
                  });
                },
              ),
              TextField(
                controller: noteCtl,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '这次做这件事的补充说明…',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('记录'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.events.addRecord(widget.event.id!, occurred, noteCtl.text.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('已记录「${widget.event.name}」'),
          duration: const Duration(seconds: 2)),
    );
    // 记录后自动展开，方便看到新记录在热力图上生效。
    if (!_expanded) setState(() => _expanded = true);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除事件'),
        content: Text('将删除「${widget.event.name}」及其全部记录，确定吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirm == true) {
      await widget.events.removeEvent(widget.event.id!);
    }
  }

  /// 更新折线图悬停索引；变化才 setState，避免频繁重建。
  void _updateHover(int idx) {
    if (_hoverIndex == idx) return;
    setState(() => _hoverIndex = idx);
  }

  /// 构建趋势图：热力图固定高度；折线图包一层 MouseRegion 支持悬停 tooltip。
  Widget _buildChart(ThemeData theme, Color color, Map<DateTime, int> counts,
      TrendKind trendKind) {
    if (trendKind == TrendKind.heatmap) {
      return SizedBox(
        height: 92,
        width: double.infinity,
        child: CustomPaint(
          painter: HeatmapPainter(counts: counts, themeColor: color),
        ),
      );
    }
    // 折线图：LayoutBuilder 拿到实际宽度，MouseRegion 反算悬停索引。
    return SizedBox(
      height: 92,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final days = TrendLinePainter.effectiveDays(counts);
          return MouseRegion(
            onHover: (e) {
              // 绘图左留白 24，曲线在 [24, w] 之间；反算悬停天数索引。
              final per = (w - 24) / (days - 1);
              if (per <= 0) return;
              final hover = ((e.localPosition.dx - 24) / per)
                  .round()
                  .clamp(0, days - 1);
              _updateHover(hover);
            },
            onExit: (_) => _updateHover(-1),
            child: _TrendPaint(
              counts: counts,
              themeColor: color,
              labelColor: GithubStyle.textMuted,
              hoverIndex: _hoverIndex,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trendKind = context.watch<SettingsProvider>().trendKind;
    final records = widget.events.recordsOf(widget.event.id!);
    final total = records.length;
    final last = records.isEmpty ? null : records.first.occurredAt;
    final summary = widget.ai.summaryOf(widget.event.id!);
    final counts = countByDay(records.map((r) => r.occurredAt));

    return GlassCard(
      // Builder 在 GlassCard 的 Theme 覆盖之内取主题，反色才会作用到卡片文字。
      child: Builder(builder: (context) {
        final theme = Theme.of(context);
        final color = theme.colorScheme.primary;
        return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- 头部紧凑摘要行（始终显示）----
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(GithubStyle.radius),
                ),
                child: Icon(Icons.flag_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.event.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: GithubStyle.text)),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.event.category} · 共 $total 次'
                      '${last == null ? '' : ' · 最近 ${last.month}/${last.day}'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: GithubStyle.textMuted),
                    ),
                  ],
                ),
              ),
              // 记录：本卡片核心高频动作，独立突出。
              FilledButton.icon(
                onPressed: () => _openRecordDialog(context),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('记录'),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: _expanded ? '收起' : '展开',
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ),
            ],
          ),
          // ---- AI 摘要默认可见，但限 2 行预览；未生成且无错误时不占位 ----
          if (summary != null || widget.ai.error != null) ...[
            const SizedBox(height: 8),
            if (summary != null)
              Text(
                _stripMarkdown(summary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: GithubStyle.textMuted, height: 1.4),
              )
            else
              Text(
                'AI 总结生成失败：${widget.ai.error}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: GithubStyle.danger),
              ),
          ],
          // ---- 展开区：热力图 + 关键词 + AI 总结 + 删除 ----
          if (_expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: GithubStyle.border),
            const SizedBox(height: 12),
            // 关键数字统计：让用户一眼看到近 7/30 天与累计次数。
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    '近7天 ${widget.events.countWithin(widget.event.id!, 7)} 次',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: GithubStyle.text),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '近30天 ${widget.events.countWithin(widget.event.id!, 30)} 次',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: GithubStyle.text),
                  ),
                  const Spacer(),
                  Text(
                    '累计 $total 次',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: GithubStyle.textMuted),
                  ),
                ],
              ),
            ),
            _buildChart(theme, color, counts, trendKind),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: widget.ai.generating ? null : () => widget.ai.generateEvent(widget.event),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('AI 总结'),
                ),
                const Spacer(),
                if (widget.event.keywordList.isNotEmpty)
                  Expanded(
                    child: Text(
                      '关键词：${widget.event.keywordList.join(' / ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: GithubStyle.textMuted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => _confirmDelete(context),
              style: TextButton.styleFrom(foregroundColor: GithubStyle.danger),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('删除事件'),
            ),
          ],
        ],
        );
      }),
    );
  }
}

/// 折线图 CustomPaint 包装：把外部悬停索引注入 painter，触发 tooltip 重绘。
class _TrendPaint extends StatelessWidget {
  const _TrendPaint({
    required this.counts,
    required this.themeColor,
    required this.labelColor,
    required this.hoverIndex,
  });

  final Map<DateTime, int> counts;
  final Color themeColor;
  final Color labelColor;
  final int hoverIndex;

  @override
  Widget build(BuildContext context) {
    final painter = TrendLinePainter(
      counts: counts,
      themeColor: themeColor,
      labelColor: labelColor,
    )..hoverIndex = hoverIndex;
    return CustomPaint(painter: painter, size: Size.infinite);
  }
}

/// 把 AI 返回的 Markdown 清洗成适合 2 行预览的纯文本：
/// 去掉行首的标题/列表/引用符号与行内的加粗、斜体、删除线、行内代码、链接标记，
/// 让预览显示可读内容而非原始标签，与全局总结卡片（MarkdownWidget 渲染）观感一致。
String _stripMarkdown(String markdown) {
  final lines = markdown.split('\n').map((line) {
    var l = line.trim();
    // 行首符号：标题 #、引用 >、任务框、无序/有序列表、分隔线 ---、表格分隔 |---
    l = l.replaceFirst(RegExp(r'^(#{1,6}|>|-{3,}|>|\d+\.\s|[-*+]\s|\[[xX ]\]\s)'), '');
    // 表格行首尾的竖线去掉。
    l = l.replaceAll('|', ' ');
    // 行内标记：加粗/斜体/删除线/行内代码、链接 [text](url) -> text。
    l = l.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1)!);
    l = l.replaceAll(RegExp(r'(\*\*|__|\*|_|~~|`+)'), '');
    return l;
  }).where((l) => l.isNotEmpty);
  return lines.join('\n').trim();
}
