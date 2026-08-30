import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/events_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_summary_provider.dart';
import '../ui/heatmap.dart';
import '../ui/trend_line.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final trendKind = context.watch<SettingsProvider>().trendKind;
    final records = widget.events.recordsOf(widget.event.id!);
    final total = records.length;
    final last = records.isEmpty ? null : records.first.occurredAt;
    final summary = widget.ai.summaryOf(widget.event.id!);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- 头部紧凑摘要行（始终显示）----
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.flag_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.event.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.event.category} · 共 $total 次'
                      '${last == null ? '' : ' · 最近 ${last.month}/${last.day}'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.78)),
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
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.78),
                    height: 1.4),
              )
            else
              Text(
                'AI 总结生成失败：${widget.ai.error}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
          ],
          // ---- 展开区：热力图 + 关键词 + AI 总结 + 删除 ----
          if (_expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              width: double.infinity,
              child: CustomPaint(
                painter: trendKind == TrendKind.heatmap
                    ? HeatmapPainter(
                        counts: countByDay(records.map((r) => r.occurredAt)),
                        themeColor: color,
                      )
                    : TrendLinePainter(
                        counts: countByDay(records.map((r) => r.occurredAt)),
                        themeColor: color,
                      ),
              ),
            ),
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
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.78)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => _confirmDelete(context),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('删除事件'),
            ),
          ],
        ],
      ),
    );
  }
}
