import 'package:flutter/material.dart';

/// 近 365 天趋势折线图：
/// - 日频次经 7 日滚动均值后以 Catmull-Rom 平滑成曲线；
/// - 左侧整数频次刻度 + 底部月份标注，阅读有参照；
/// - 有记录的日期打主题色圆点，曲线下方渐变面积填充。
class TrendLinePainter extends CustomPainter {
  TrendLinePainter({
    required this.counts, // 日期(仅取年月日) -> 当日次数
    required this.themeColor,
    required this.labelColor, // 刻度/月份文字颜色（跟随面板反色）
    this.days = 365,
  });

  final Map<DateTime, int> counts;
  final Color themeColor;
  final Color labelColor;
  final int days;

  static const double _padLeft = 24;
  static const double _padRight = 8;
  static const double _padTop = 10;
  static const double _padBottom = 16;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1) 对齐到逐日频次数组（末尾为今天）。
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    final daily = List<int>.filled(days, 0);
    for (final e in counts.entries) {
      final idx =
          DateTime(e.key.year, e.key.month, e.key.day).difference(start).inDays;
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
    // 纵轴顶格取整，保证网格线落在整数频次上。
    final yMax = rawMax <= 0 ? 1.0 : rawMax.ceilToDouble();

    final chartW = size.width - _padLeft - _padRight;
    final chartH = size.height - _padTop - _padBottom;
    double x(int i) => _padLeft + i / (days - 1) * chartW;
    double y(double v) => _padTop + chartH * (1 - v / yMax);

    // 3) 整数频次网格线 + 左侧刻度数字。
    final gridStep = (yMax / 3).ceilToDouble().clamp(1, double.infinity);
    final grid = Paint()
      ..color = themeColor.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (var g = gridStep; g <= yMax; g += gridStep) {
      final gy = y(g.toDouble());
      canvas.drawLine(Offset(_padLeft, gy), Offset(size.width - _padRight, gy), grid);
      _paintLabel(canvas, g.toInt().toString(),
          Offset(_padLeft - 4, gy), align: 1.0);
    }
    // 基线。
    canvas.drawLine(
      Offset(_padLeft, y(0)),
      Offset(size.width - _padRight, y(0)),
      Paint()
        ..color = themeColor.withValues(alpha: 0.22)
        ..strokeWidth = 1,
    );

    // 4) 底部月份标注（每 2 个月一个，避免拥挤）。
    int? lastLabelMonth;
    for (var i = 0; i < days; i++) {
      final d = start.add(Duration(days: i));
      if (d.month != lastLabelMonth && d.day <= 3 && i > 0) {
        lastLabelMonth = d.month;
        if (d.month.isOdd) {
          _paintLabel(canvas, '${d.month}月',
              Offset(x(i), size.height - _padBottom + 3),
              align: 0.5, small: true);
        }
      }
    }

    // 5) Catmull-Rom 平滑曲线。
    final pts = [for (var i = 0; i < days; i++) Offset(x(i), y(smoothed[i]))];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < days; i++) {
      final p0 = pts[(i - 2).clamp(0, days - 1)];
      final p1 = pts[i - 1];
      final p2 = pts[i];
      final p3 = pts[(i + 1).clamp(0, days - 1)];
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      line.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    // 6) 曲线下方渐变面积。
    final area = Path.from(line)
      ..lineTo(pts.last.dx, y(0))
      ..lineTo(pts.first.dx, y(0))
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            themeColor.withValues(alpha: 0.30),
            themeColor.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTRB(0, 0, size.width, size.height)),
    );

    // 7) 描边曲线（主题色渐变，左淡右浓强调“最近”）。
    canvas.drawPath(
      line,
      Paint()
        ..shader = LinearGradient(
          colors: [
            themeColor.withValues(alpha: 0.45),
            themeColor,
          ],
        ).createShader(Rect.fromLTRB(_padLeft, 0, size.width, 0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    // 8) 有记录的日期打圆点；末端亮点强调最新状态。
    final dot = Paint()..color = themeColor;
    for (var i = 0; i < days; i++) {
      if (daily[i] > 0) {
        canvas.drawCircle(Offset(x(i), y(daily[i].toDouble())), 2.2, dot);
      }
    }
    canvas.drawCircle(
      Offset(x(days - 1), y(smoothed.last)),
      3,
      Paint()..color = themeColor,
    );
  }

  /// 用 TextPainter 画小字标签；align: 0 左对齐、0.5 居中、1 右对齐（垂直居中于 y）。
  void _paintLabel(Canvas canvas, String text, Offset anchor,
      {double align = 0, bool small = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: small ? 9 : 10,
          color: labelColor.withValues(alpha: 0.75),
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      1.0 => anchor.dx - tp.width,
      0.5 => anchor.dx - tp.width / 2,
      _ => anchor.dx,
    };
    final dy = small ? anchor.dy : anchor.dy - tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant TrendLinePainter old) {
    return old.themeColor != themeColor ||
        old.labelColor != labelColor ||
        old.counts.length != counts.length ||
        old.days != days;
  }
}
