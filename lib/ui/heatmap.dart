import 'package:flutter/material.dart';

/// GitHub 风格 365 天热力图，按事件记录频次着色，主题色渐变。
class HeatmapPainter extends CustomPainter {
  HeatmapPainter({
    required this.counts, // 日期(仅取年月日) -> 当日次数
    required this.themeColor,
    this.weeks = 53,
  });

  final Map<DateTime, int> counts;
  final Color themeColor;
  final int weeks;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 3.0;
    final cell = (size.height - gap * 6) / 7;
    final today = _dayOf(DateTime.now());

    // 起点：weeks 周前的周一。
    final start = today
        .subtract(Duration(days: (weeks - 1) * 7))
        .subtract(Duration(days: today.weekday - 1));

    final empty = Paint()..color = themeColor.withValues(alpha: 0.08);
    for (int w = 0; w < weeks; w++) {
      for (int d = 0; d < 7; d++) {
        final day = start.add(Duration(days: w * 7 + d));
        if (day.isAfter(today)) return;
        final x = w * (cell + gap);
        final y = d * (cell + gap);
        final count = counts[_dayOf(day)] ?? 0;
        final rect = Rect.fromLTWH(x, y, cell, cell);
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.28));
        if (count == 0) {
          canvas.drawRRect(rrect, empty);
        } else {
          // 1 次 -> 0.35；≥4 次 -> 1.0，线性增强。
          final t = ((count - 1) / 3).clamp(0.0, 1.0);
          final paint = Paint()
            ..color = Color.lerp(
                themeColor.withValues(alpha: 0.35), themeColor, t)!;
          canvas.drawRRect(rrect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant HeatmapPainter old) {
    return old.themeColor != themeColor ||
        old.counts.length != counts.length ||
        old.weeks != weeks;
  }
}

/// 记录 Map：事件记录列表 -> 日期计数。
Map<DateTime, int> countByDay(Iterable<DateTime> occurredAtList) {
  final map = <DateTime, int>{};
  for (final dt in occurredAtList) {
    final key = DateTime(dt.year, dt.month, dt.day);
    map[key] = (map[key] ?? 0) + 1;
  }
  return map;
}
