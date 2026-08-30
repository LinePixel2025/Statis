import 'package:flutter/material.dart';

/// 近 365 天趋势折线图：日频次经 7 日滚动均值平滑，主题色描边 + 渐变面积填充。
class TrendLinePainter extends CustomPainter {
  TrendLinePainter({
    required this.counts, // 日期(仅取年月日) -> 当日次数
    required this.themeColor,
    this.days = 365,
  });

  final Map<DateTime, int> counts;
  final Color themeColor;
  final int days;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1) 对齐到逐日频次数组（末尾为今天）。
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    final daily = List<int>.filled(days, 0);
    for (final e in counts.entries) {
      final idx = DateTime(e.key.year, e.key.month, e.key.day).difference(start).inDays;
      if (idx >= 0 && idx < days) daily[idx] += e.value;
    }

    // 2) 7 日中心滚动均值，抹平单日尖刺突出趋势。
    final smoothed = List<double>.generate(days, (i) {
      final lo = (i - 3).clamp(0, days - 1);
      final hi = (i + 3).clamp(0, days - 1);
      var sum = 0;
      for (var j = lo; j <= hi; j++) {
        sum += daily[j];
      }
      return sum / (hi - lo + 1);
    });

    final rawMax = smoothed.reduce((a, b) => a > b ? a : b);
    final top = rawMax <= 0 ? 1.0 : rawMax;

    const topPad = 4.0;
    const basePad = 6.0; // 底部基线留白
    final chartH = size.height - topPad - basePad;
    double x(int i) => i / (days - 1) * size.width;
    double y(double v) => topPad + chartH * (1 - v / top);

    // 3) 整数频次网格线与基线。
    final grid = Paint()
      ..color = themeColor.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final gridMax = top > 4 ? 4 : top.floor();
    for (var g = 1; g <= gridMax; g++) {
      canvas.drawLine(Offset(0, y(g.toDouble())), Offset(size.width, y(g.toDouble())), grid);
    }
    canvas.drawLine(
      Offset(0, y(0)),
      Offset(size.width, y(0)),
      Paint()
        ..color = themeColor.withValues(alpha: 0.18)
        ..strokeWidth = 1,
    );

    // 4) 折线 + 面积。
    final line = Path();
    for (var i = 0; i < days; i++) {
      final p = Offset(x(i), y(smoothed[i]));
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
      }
    }
    final area = Path.from(line)
      ..lineTo(size.width, y(0))
      ..lineTo(0, y(0))
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            themeColor.withValues(alpha: 0.32),
            themeColor.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTRB(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = themeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    // 5) 末端亮点。
    canvas.drawCircle(
      Offset(x(days - 1), y(smoothed.last)),
      3,
      Paint()..color = themeColor,
    );
  }

  @override
  bool shouldRepaint(covariant TrendLinePainter old) {
    return old.themeColor != themeColor ||
        old.counts.length != counts.length ||
        old.days != days;
  }
}
