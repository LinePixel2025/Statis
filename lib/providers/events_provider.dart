import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';

/// 事件与记录的全局状态，负责与数据库同步并通知界面刷新。
class EventsProvider extends ChangeNotifier {
  EventsProvider(this._db);

  final DatabaseService _db;

  List<Event> _events = [];
  List<EventRecord> _records = [];

  List<Event> get events => List.unmodifiable(_events);
  List<EventRecord> get records => List.unmodifiable(_records);

  /// 从数据库加载全部数据（应用启动时调用）。
  Future<void> loadAll() async {
    _events = await _db.loadEvents();
    _records = await _db.loadAllRecords();
    notifyListeners();
  }

  /// 某事件的全部记录，按发生时间倒序。
  List<EventRecord> recordsOf(int eventId) =>
      _records.where((r) => r.eventId == eventId).toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  Future<void> addEvent(String name, String category,
      {bool aiEnabled = true, String keywords = ''}) async {
    final event = Event(
      name: name,
      category: category,
      aiEnabled: aiEnabled,
      keywords: keywords,
      createdAt: DateTime.now(),
    );
    final id = await _db.insertEvent(event);
    _events = [event.copyWith(id: id), ..._events];
    notifyListeners();
  }

  Future<void> updateEvent(Event event) async {
    await _db.updateEvent(event);
    _events = [
      for (final e in _events) if (e.id == event.id) event else e
    ];
    notifyListeners();
  }

  Future<void> removeEvent(int eventId) async {
    await _db.deleteEvent(eventId);
    _events = _events.where((e) => e.id != eventId).toList();
    _records = _records.where((r) => r.eventId != eventId).toList();
    notifyListeners();
  }

  /// 记录一次事件发生。
  Future<void> addRecord(int eventId, DateTime occurredAt, String note) async {
    final record = EventRecord(
      eventId: eventId,
      occurredAt: occurredAt,
      note: note,
      createdAt: DateTime.now(),
    );
    final id = await _db.insertRecord(record);
    _records = [record.copyWith(id: id), ..._records];
    notifyListeners();
  }

  Future<void> removeRecord(int recordId) async {
    await _db.deleteRecord(recordId);
    _records = _records.where((r) => r.id != recordId).toList();
    notifyListeners();
  }

  /// 标记事件已完成一次 AI 总结（供定期生成判断）。
  Future<void> markSummarized(int eventId) async {
    final now = DateTime.now();
    await _db.markSummarized(eventId, now);
    _events = [
      for (final e in _events)
        if (e.id == eventId) e.copyWith(lastSummaryAt: now) else e
    ];
    notifyListeners();
  }

  // ---- 统计辅助 ----

  /// 事件总发生次数。
  int countOf(int eventId) =>
      _records.where((r) => r.eventId == eventId).length;

  /// 最近 [days] 天内的发生次数。
  int countWithin(int eventId, int days) {
    final since = DateTime.now().subtract(Duration(days: days));
    return _records
        .where((r) => r.eventId == eventId && r.occurredAt.isAfter(since))
        .length;
  }

  /// 最近一次发生时间，无记录返回 null。
  DateTime? lastOccurredAt(int eventId) {
    DateTime? latest;
    for (final r in _records) {
      if (r.eventId != eventId) continue;
      if (latest == null || r.occurredAt.isAfter(latest)) {
        latest = r.occurredAt;
      }
    }
    return latest;
  }
}
