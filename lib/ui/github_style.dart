import 'package:flutter/material.dart';

/// GitHub light_default 配色与界面常量（对齐 github.com 浅色主题）。
/// 强调色除外——强调色仍由用户自定义主题色驱动，这里的 accent 仅作兜底/备用。
abstract final class GithubStyle {
  // ---- 画布与表面 ----
  static const Color canvas = Color(0xFFF6F8FA); // 窗口画布底色
  static const Color surface = Color(0xFFFFFFFF); // 卡片/顶栏/对话框表面
  static const Color border = Color(0xFFD0D7DE); // 主边框
  static const Color borderSubtle = Color(0xFFD8DEE4); // 细分隔线

  // ---- 文字 ----
  static const Color text = Color(0xFF24292F); // 正文/标题
  static const Color textMuted = Color(0xFF57606A); // 次要文字

  // ---- 强调 / 危险 ----
  static const Color accent = Color(0xFF0969DA); // GitHub 蓝（备用强调）
  static const Color danger = Color(0xFFCF222E); // 危险红（删除等）

  // ---- 热力图 ----
  static const Color heatmapEmpty = Color(0xFFEBEDF0); // 热力图空档格子

  // ---- 按钮悬停 / 表面高亮 ----
  static const Color canvasHover = Color(0xFFF3F4F6);

  // ---- 圆角 ----
  static const double radius = 6;
}
