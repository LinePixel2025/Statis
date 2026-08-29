import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import 'ai_service.dart';
import '../providers/events_provider.dart';
import '../providers/settings_provider.dart';

/// AI 总结的缓存与定期调度：
/// - 保存每个事件的总结文本与全局总结文本（内存缓存，生成后展示）；
/// - 应用启动及运行期间按周期检查并自动生成过期总结。
class AiSummaryProvider extends ChangeNotifier {
  AiSummaryProvider(this._ai, this._events, this._settings) {
    _events.addListener(_onEventsChanged);
  }

  final AiService _ai;
  final EventsProvider _events;
  final SettingsProvider _settings;

  final Map<int, String> _eventSummaries = {};
  String? _globalSummary;
  String? _error;
  bool _generatingEvent = false;
  bool _generatingGlobal = false;
  Timer? _timer;

  String? summaryOf(int eventId) => _eventSummaries[eventId];
  String? get globalSummary => _globalSummary;
  String? get error => _error;
  bool get generatingEvent => _generatingEvent;
  bool get generatingGlobal => _generatingGlobal;
  bool get generating => _generatingEvent || _generatingGlobal;

  void _onEventsChanged() {
    // 事件被删除时，同步清理其总结缓存。
    final ids = _events.events.map((e) => e.id).toSet();
    _eventSummaries.removeWhere((k, _) => !ids.contains(k));
    if (_events.events.isEmpty) _globalSummary = null;
    notifyListeners();
  }

  /// 手动生成单个事件总结。
  Future<void> generateEvent(Event event) async {
    if (event.id == null || generating) return;
    _generatingEvent = true;
    _error = null;
    notifyListeners();
    try {
      final text = await _ai.summarizeEvent(event);
      _eventSummaries[event.id!] = text;
      await _events.markSummarized(event.id!);
    } on AiException catch (e) {
      _error = e.message;
    } finally {
      _generatingEvent = false;
      notifyListeners();
    }
  }

  /// 手动生成全局总结。
  Future<void> generateGlobal() async {
    if (generating) return;
    _generatingGlobal = true;
    _error = null;
    notifyListeners();
    try {
      _globalSummary = await _ai.summarizeGlobal();
    } on AiException catch (e) {
      _error = e.message;
    } finally {
      _generatingGlobal = false;
      notifyListeners();
    }
  }

  /// 启动自动调度：立即检查一次过期总结，此后每小时检查一次。
  void startAutoSchedule() {
    _timer?.cancel();
    _autoCheck();
    _timer = Timer.periodic(const Duration(hours: 1), (_) => _autoCheck());
  }

  Future<void> _autoCheck() async {
    if (!_settings.aiConfigured || generating) return;
    final due = _ai.dueEvents();
    if (due.isEmpty && _globalSummary != null) return;
    // 首次启动时全局总结也没有，一并生成。
    for (final event in due.take(3)) {
      await generateEvent(event);
    }
    if (_globalSummary == null || due.isNotEmpty) {
      await generateGlobal();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _events.removeListener(_onEventsChanged);
    _ai.dispose();
    super.dispose();
  }
}
