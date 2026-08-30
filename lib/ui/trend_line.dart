import 'package:flutter/material.dart';

import 'github_style.dart';

/// 近 N 天趋势折线图（窗口自适应数据跨度）：
/// - 日频次经 7 日滚动均值后以 Catmull-Rom 平滑成曲线；
/// - 窗口按数据实际跨度伸缩（至少 30 天、最多 365 天），稀疏记录时曲线摆动可见；
/// - 峰值处标注圆点与「峰值 N/日」，左侧整数刻度 + 底部月份标注；
/// - 支持鼠标悬停，显示该点日期与当日次数。
class TrendLinePainter extends CustomPainter {
  TrendLinePainter({
    required this.counts, // 日期(仅取年月日) -> 当日次数
    required this.themeColor,
    required this.labelColor, // 刻度/月份文字颜色
    this.daysOverride, // 允许外部固定窗口；null 则按数据跨度自动计算
  });

  final Map<DateTime, int> counts;
  final Color themeColor;
  final Color labelColor;
  final int? daysOverride;

  static const double _padLeft = 24;
  static const double _padRight = 8;
  static const double _padTop = 10;
  static const double _padBottom = 16;

  /// 滑动平均窗口（用于平滑单日尖刺）。
  static const int _smooth = 7;

  /// 内部状态：当前悬停的天数索引（从窗口起始日算起），-1 表示无悬停。
  int hoverIndex = -1;

  /// 依据 counts 计算实际展示窗口天数（至少 [_minDays] 天，最多 365 天）。
  static int effectiveDays(Map<DateTime, int> counts, {int? override}) {
    if (override != null && override > 0) return override;
    if (counts.isEmpty) return 30;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 最早有记录的日子。
    DateTime? earliest;
    for (final d in counts.keys) {
      final day = DateTime(d.year, d.month, d.day);
      if (earliest == null || day.isBefore(earliest)) earliest = day;
    }
    if (earliest == null) return 30;
    final span = today.difference(earliest).inDays + 1;
    // 预留 [2 * _smooth] 天给滑动均值采样，避免滑动窗口边缘被截断。
    return span.clamp(30, 365);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final days = effectiveDays(counts, override: daysOverride);

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
      final lo = (i - _smooth ~/ 2).clamp(0, days - 1);
      final hi = (i + _smooth ~/ 2).clamp(0, days - 1);
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
      ..color = GithubStyle.border.withValues(alpha: 0.6)
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
        ..color = GithubStyle.border
        ..strokeWidth = 1,
    );

    // 4) 底部时间标注：窗口宽则按月、窗口短则按周/半月自适应，避免重叠。
    final labelGap = _timeLabelGap(days);
    _paintTimeLabels(canvas, start, days, size, labelGap, x);

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

    // 8) 有记录的日期打圆点（淡色）。
    final dot = Paint()..color = themeColor.withValues(alpha: 0.25);
    for (var i = 0; i < days; i++) {
      if (daily[i] > 0) {
        canvas.drawCircle(Offset(x(i), y(daily[i].toDouble())), 2.0, dot);
      }
    }

    // 9) 峰值标注：平滑曲线最高点。
    var peakIdx = 0;
    for (var i = 1; i < days; i++) {
      if (smoothed[i] > smoothed[peakIdx]) peakIdx = i;
    }
    if (smoothed[peakIdx] > 0) {
      final peakP = Offset(x(peakIdx), y(smoothed[peakIdx]));
      canvas.drawCircle(
          peakP, 3.5, Paint()..color = themeColor);
      // 峰值标签，置于点上方；靠右时左移避免出界。
      final peakLabel = '峰值 ${smoothed[peakIdx].round()}/日';
      final tp = TextPainter(
        text: TextSpan(
          text: peakLabel,
          style: TextStyle(
            fontSize: 9,
            color: themeColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelX = (peakP.dx - tp.width / 2)
          .clamp(_padLeft, size.width - _padRight - tp.width);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(labelX, peakP.dy - 20, tp.width + 8, tp.height + 4),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      tp.paint(
          canvas,
          Offset(labelX + 4, peakP.dy - 18));
    }

    // 10) 悬停高亮：竖线 + 当日数据点 + 小工具条。
    final hover = hoverIndex;
    if (hover >= 0 && hover < days) {
      final hx = x(hover);
      final hy = y(smoothed[hover]);
      // 竖参考线。
      canvas.drawLine(
        Offset(hx, _padTop),
        Offset(hx, size.height - _padBottom),
        Paint()
          ..color = themeColor.withValues(alpha: 0.15)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(hx, hy), 4, Paint()..color = themeColor);
      canvas.drawCircle(
        Offset(hx, hy),
        7,
        Paint()
          ..color = themeColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      // 工具条文本。
      final d = start.add(Duration(days: hover));
      final label =
          '${d.month}/${d.day} · ${daily[hover]} 次';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final boxW = tp.width + 12;
      final boxH = tp.height + 6;
      // 工具条默认放点上方，避免出界时移到下方。
      var bx = (hx - boxW / 2)
          .clamp(0.0, size.width - boxW);
      var by = hy - boxH - 10;
      if (by < 0) by = hy + 10;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, boxW, boxH),
        const Radius.circular(4),
      );
      canvas.drawRRect(rrect, Paint()..color = const Color(0xD9202629));
      tp.paint(canvas, Offset(bx + 6, by + 3));
    }
  }

  /// 根据窗口天数决定底部时间标签的间隔单位。
  double _timeLabelGap(int days) {
    // 返回标签间隔的天数：窗口越短间隔越小，避免重叠又保留足够信息。
    if (days <= 45) return 7; // 每周一标
    if (days <= 120) return 30; // 每 30 天一标
    return 60; // 每 2 个月一标
  }

  void _paintTimeLabels(Canvas canvas, DateTime start, int days, Size size,
      double gapDays, double Function(int) xOf) {
    // 采样若干时间点作为标签锚点。
    final anchors = <int>[];
    for (var i = 0; i < days; i += gapDays.round()) {
      anchors.add(i);
    }
    if (anchors.isEmpty || anchors.last != days - 1) anchors.add(days - 1);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final i in anchors) {
      final d = start.add(Duration(days: i));
      final text = days <= 45
          ? '${d.month}/${d.day}'
          : '${d.month}月';
      tp.text = TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          color: labelColor.withValues(alpha: 0.75),
          height: 1.0,
        ),
      );
      tp.layout();
      final dx = (xOf(i) - tp.width / 2)
          .clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, size.height - _padBottom + 4));
    }
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
        old.daysOverride != daysOverride ||
        old.hoverIndex != hoverIndex;
  }
}
