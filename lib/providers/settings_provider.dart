import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 背景类型。
enum BgKind { none, color, image }

/// 事件卡片展开区的趋势展示形式（可在设置-个性化中切换，持久化）。
enum TrendKind { line, heatmap }

/// 应用设置：主题色、背景、AI 配置、总结周期。
class SettingsProvider extends ChangeNotifier {
  static const _keyThemeColor = 'theme_color';
  static const _keyBgKind = 'bg_kind';
  static const _keyBgValue = 'bg_value';
  static const _keyBgBlur = 'bg_blur';
  static const _keyAiBaseUrl = 'ai_base_url';
  static const _keyAiApiKey = 'ai_api_key';
  static const _keyAiModel = 'ai_model';
  static const _keySummaryDays = 'summary_days';
  static const _keyTrendKind = 'trend_kind';

  /// 预设主题色（个性化选项卡可选）。
  static const presetColors = <Color>[
    Color(0xFF6C8CFF), // 静谧蓝
    Color(0xFF8E7BFF), // 梦幻紫
    Color(0xFFFF7BA9), // 樱花粉
    Color(0xFFFF9F43), // 暖阳橙
    Color(0xFF2ED573), // 薄荷绿
    Color(0xFF1FBFBD), // 青碧
  ];

  Color _themeColor = presetColors.first;
  BgKind _bgKind = BgKind.none;
  String _bgValue = '';
  double _bgBlur = 0;
  String _aiBaseUrl = 'https://api.deepseek.com/v1';
  String _aiApiKey = '';
  String _aiModel = 'deepseek-chat';
  int _summaryDays = 7;
  TrendKind _trendKind = TrendKind.line;

  Color get themeColor => _themeColor;
  BgKind get bgKind => _bgKind;
  String get bgValue => _bgValue;
  double get bgBlur => _bgBlur;
  String get aiBaseUrl => _aiBaseUrl;
  String get aiApiKey => _aiApiKey;
  String get aiModel => _aiModel;

  /// AI 总结自动生成的周期（天）。
  int get summaryDays => _summaryDays;

  /// 事件趋势展示形式（折线图 / 热力图）。
  TrendKind get trendKind => _trendKind;
  bool get aiConfigured => _aiApiKey.isNotEmpty && _aiBaseUrl.isNotEmpty;

  /// 背景图片文件是否仍存在（文件可能被移动/删除）。
  bool get bgImageExists =>
      _bgKind == BgKind.image &&
      _bgValue.isNotEmpty &&
      File(_bgValue).existsSync();

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _themeColor = Color(sp.getInt(_keyThemeColor) ?? presetColors.first.toARGB32());
    _bgKind = BgKind.values.firstWhere(
      (k) => k.name == (sp.getString(_keyBgKind) ?? 'none'),
      orElse: () => BgKind.none,
    );
    _bgValue = sp.getString(_keyBgValue) ?? '';
    _bgBlur = sp.getDouble(_keyBgBlur) ?? 0;
    _aiBaseUrl = sp.getString(_keyAiBaseUrl) ?? _aiBaseUrl;
    _aiApiKey = sp.getString(_keyAiApiKey) ?? '';
    _aiModel = sp.getString(_keyAiModel) ?? _aiModel;
    _summaryDays = sp.getInt(_keySummaryDays) ?? 7;
    _trendKind = TrendKind.values.firstWhere(
      (k) => k.name == (sp.getString(_keyTrendKind) ?? 'line'),
      orElse: () => TrendKind.line,
    );
    notifyListeners();
  }

  Future<void> _persist(String key, Object value) async {
    final sp = await SharedPreferences.getInstance();
    if (value is int) await sp.setInt(key, value);
    if (value is double) await sp.setDouble(key, value);
    if (value is String) await sp.setString(key, value);
  }

  void setThemeColor(Color color) {
    if (color.toARGB32() == _themeColor.toARGB32()) return;
    _themeColor = color;
    _persist(_keyThemeColor, color.toARGB32());
    notifyListeners();
  }

  /// 设置背景：类型、取值（颜色字符串或图片路径）、模糊强度。
  void setBackground(BgKind kind, String value, double blur) {
    _bgKind = kind;
    _bgValue = value;
    _bgBlur = blur;
    _persist(_keyBgKind, kind.name);
    _persist(_keyBgValue, value);
    _persist(_keyBgBlur, blur);
    notifyListeners();
  }

  void setAiConfig(String baseUrl, String apiKey, String model) {
    _aiBaseUrl = baseUrl.trim();
    _aiApiKey = apiKey.trim();
    _aiModel = model.trim();
    _persist(_keyAiBaseUrl, _aiBaseUrl);
    _persist(_keyAiApiKey, _aiApiKey);
    _persist(_keyAiModel, _aiModel);
    notifyListeners();
  }

  void setSummaryDays(int days) {
    if (days < 1) days = 1;
    if (days == _summaryDays) return;
    _summaryDays = days;
    _persist(_keySummaryDays, days);
    notifyListeners();
  }

  void setTrendKind(TrendKind kind) {
    if (kind == _trendKind) return;
    _trendKind = kind;
    _persist(_keyTrendKind, kind.name);
    notifyListeners();
  }
}
