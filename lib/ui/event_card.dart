import 'package:flutter/material.dart';

import '../models/models.dart';
import '../providers/events_provider.dart';
import '../services/ai_summary_provider.dart';
import '../ui/heatmap.dart';
import 'glass_card.dart';

/// 主界面事件卡片：名称、分类、记录按钮、热力图、AI 总结摘要。
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.events, required this.ai});

  final Event event;
  final EventsProvider events;
  final AiSummaryProvider ai;

  Future<void> _openRecordDialog(BuildContext context) async {
    final noteCtl = TextEditingController();
    DateTime occurred = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('记录「${event.name}」'),
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
    await events.addRecord(event.id!, occurred, noteCtl.text.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('已记录「${event.name}」'),
          duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final records = events.recordsOf(event.id!);
    final total = records.length;
    final last = records.isEmpty ? null : records.first.occurredAt;
    final summary = ai.summaryOf(event.id!);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    Text(event.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${event.category} · 共 $total 次'
                      '${last == null ? '' : ' · 最近 ${last.month}/${last.day}'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // 记录按钮：本卡片核心动作。
              FilledButton.icon(
                onPressed: () => _openRecordDialog(context),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('记录'),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) async {
                  if (v == 'delete' && context.mounted) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除事件'),
                        content: Text('将删除「${event.name}」及其全部记录，确定吗？'),
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
                    if (confirm == true) events.removeEvent(event.id!);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('删除事件')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            width: double.infinity,
            child: CustomPaint(
              painter: HeatmapPainter(
                counts: countByDay(records.map((r) => r.occurredAt)),
                themeColor: color,
              ),
            ),
          ),
          if (summary != null || ai.error != null) ...[
            const SizedBox(height: 12),
            if (summary != null)
              Text(
                summary,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
              )
            else
              Text(
                'AI 总结生成失败：${ai.error}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: ai.generating ? null : () => ai.generateEvent(event),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('AI 总结'),
              ),
              const Spacer(),
              if (event.keywordList.isNotEmpty)
                Expanded(
                  child: Text(
                    '关键词：${event.keywordList.join(' / ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
