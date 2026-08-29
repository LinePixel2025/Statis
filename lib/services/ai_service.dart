import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../providers/events_provider.dart';
import '../providers/settings_provider.dart';

/// OpenAI 兼容 chat/completions 客户端与总结生成逻辑。
/// 兼容 OpenAI / DeepSeek / Moonshot / 通义 / 智谱等提供商。
class AiService {
  AiService(this._settings, this._events);

  final SettingsProvider _settings;
  final EventsProvider _events;

  http.Client? _client;
  http.Client get _httpClient => _client ??= http.Client();

  static const _timeout = Duration(seconds: 60);

  /// 调用 chat/completions 接口，返回模型回复文本。
  Future<String> chat(String systemPrompt, String userPrompt) async {
    final s = _settings;
    if (!s.aiConfigured) {
      throw AiException('尚未配置 AI 服务，请在设置中填写 Base URL 与 API Key');
    }
    final base = s.aiBaseUrl.endsWith('/')
        ? s.aiBaseUrl.substring(0, s.aiBaseUrl.length - 1)
        : s.aiBaseUrl;
    Uri uri;
    try {
      uri = Uri.parse('$base/chat/completions');
    } catch (_) {
      throw AiException('Base URL 格式不正确：${s.aiBaseUrl}');
    }

    final body = jsonEncode({
      'model': s.aiModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.6,
    });

    http.Response resp;
    try {
      resp = await _httpClient
          .post(uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${s.aiApiKey}',
              },
              body: body)
          .timeout(_timeout);
    } on TimeoutException {
      throw AiException('请求超时，请检查网络或更换服务商');
    } catch (e) {
      throw AiException('网络请求失败：$e');
    }

    if (resp.statusCode != 200) {
      String detail = resp.body;
      try {
        final j = jsonDecode(utf8.decode(resp.bodyBytes));
        if (j is Map && j['error'] is Map) {
          detail = j['error']['message']?.toString() ?? detail;
        }
      } catch (_) {}
      throw AiException('接口返回 ${resp.statusCode}：$detail');
    }

    try {
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw AiException('接口未返回任何内容');
      }
      final msg = choices.first['message'];
      return (msg?['content'] ?? '').toString().trim();
    } catch (e) {
      if (e is AiException) rethrow;
      throw AiException('解析响应失败：$e');
    }
  }

  /// 为单个事件生成总结。
  Future<String> summarizeEvent(Event event) async {
    return chat(_systemPrompt(), _eventPrompt(event));
  }

  /// 生成覆盖所有事件的全局简略总结。
  Future<String> summarizeGlobal() async {
    return chat(_systemPrompt(), _globalPrompt());
  }

  String _systemPrompt() {
    return '你是 Statis 应用的事件统计分析师。用户会给你一个重复事件的记录统计信息，'
        '请用简体中文输出一段简洁的总结，使用 Markdown。'
        '内容包括：发生频率评价、近期趋势、以及一句鼓励或建议。'
        '不要编造数据之外的信息，不要输出无关寒暄。';
  }

  String _eventPrompt(Event event) {
    final count7 = _events.countWithin(event.id!, 7);
    final count30 = _events.countWithin(event.id!, 30);
    final total = _events.countOf(event.id!);
    final last = _events.lastOccurredAt(event.id!);
    final buf = StringBuffer()
      ..writeln('事件名称：${event.name}')
      ..writeln('分类：${event.category}')
      ..writeln('总记录次数：$total')
      ..writeln('最近7天次数：$count7')
      ..writeln('最近30天次数：$count30');
    if (last != null) {
      buf.writeln('最近一次发生：${last.toIso8601String().substring(0, 10)}');
    } else {
      buf.writeln('该事件还没有任何记录');
    }
    final kws = event.keywordList;
    if (kws.isNotEmpty) {
      buf.writeln('用户关注的关键词：${kws.join('、')}。请围绕这些关键词展开分析与建议。');
    }
    return '请总结以下事件的发生情况：\n$buf';
  }

  String _globalPrompt() {
    final buf = StringBuffer('请基于以下所有事件的近期统计，输出一段 100 字左右的全局简略总结，'
        '概括整体活动情况并指出最活跃与最需要坚持的事件：\n');
    for (final e in _events.events) {
      final total = _events.countOf(e.id!);
      final count7 = _events.countWithin(e.id!, 7);
      buf.writeln('- ${e.name}（${e.category}）：共 $total 次，最近7天 $count7 次');
    }
    if (_events.events.isEmpty) buf.writeln('（暂无事件）');
    return buf.toString();
  }

  /// 找出开启 AI 且已超过总结周期、需要重新生成总结的事件。
  List<Event> dueEvents() {
    final now = DateTime.now();
    final days = _settings.summaryDays;
    return _events.events
        .where((e) =>
            e.aiEnabled &&
            e.id != null &&
            (e.lastSummaryAt == null ||
                now.difference(e.lastSummaryAt!).inDays >= days))
        .toList();
  }

  void dispose() {
    _client?.close();
  }
}

class AiException implements Exception {
  AiException(this.message);
  final String message;

  @override
  String toString() => message;
}
