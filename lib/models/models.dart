/// 事件模型：用户添加的一件会重复做的事情。
class Event {
  Event({
    this.id,
    required this.name,
    required this.category,
    this.aiEnabled = true,
    this.keywords = '',
    this.lastSummaryAt,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String category;

  /// 是否为该事件开启 AI 总结。
  final bool aiEnabled;

  /// 用户填写的关键词（逗号分隔，可为空），将注入 AI 总结提示词。
  final String keywords;

  /// 上次生成 AI 总结的时间，用于定期生成判断。
  final DateTime? lastSummaryAt;
  final DateTime createdAt;

  /// 关键词列表形式。
  List<String> get keywordList => keywords
      .split(RegExp(r'[,，;；]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Event copyWith({
    int? id,
    String? name,
    String? category,
    bool? aiEnabled,
    String? keywords,
    DateTime? lastSummaryAt,
    bool clearLastSummaryAt = false,
    DateTime? createdAt,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      keywords: keywords ?? this.keywords,
      lastSummaryAt: clearLastSummaryAt ? null : (lastSummaryAt ?? this.lastSummaryAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'ai_enabled': aiEnabled ? 1 : 0,
      'keywords': keywords,
      'last_summary_at': lastSummaryAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  static Event fromMap(Map<String, Object?> map) {
    return Event(
      id: map['id'] as int,
      name: map['name'] as String,
      category: map['category'] as String,
      aiEnabled: (map['ai_enabled'] as int) == 1,
      keywords: (map['keywords'] as String?) ?? '',
      lastSummaryAt: map['last_summary_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['last_summary_at'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

/// 记录模型：事件的一次发生，含发生时间与备注。
class EventRecord {
  EventRecord({
    this.id,
    required this.eventId,
    required this.occurredAt,
    this.note = '',
    required this.createdAt,
  });

  final int? id;
  final int eventId;
  final DateTime occurredAt;
  final String note;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'event_id': eventId,
      'occurred_at': occurredAt.millisecondsSinceEpoch,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  static EventRecord fromMap(Map<String, Object?> map) {
    return EventRecord(
      id: map['id'] as int,
      eventId: map['event_id'] as int,
      occurredAt:
          DateTime.fromMillisecondsSinceEpoch(map['occurred_at'] as int),
      note: (map['note'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  EventRecord copyWith({int? id}) {
    return EventRecord(
      id: id ?? this.id,
      eventId: eventId,
      occurredAt: occurredAt,
      note: note,
      createdAt: createdAt,
    );
  }
}
