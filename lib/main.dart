import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/events_provider.dart';
import 'providers/settings_provider.dart';
import 'services/ai_service.dart';
import 'services/ai_summary_provider.dart';
import 'services/database_service.dart';
import 'ui/main_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 窗口初始化：固定合适的最小尺寸，隐藏系统标题栏（自绘 Statis 顶栏）。
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1080, 760),
    minimumSize: Size(760, 560),
    center: true,
    title: 'Statis',
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 服务与初始数据加载。
  final db = DatabaseService();
  final settings = SettingsProvider();
  final events = EventsProvider(db);
  await settings.load();
  await events.loadAll();
  final ai = AiService(settings, events);
  final summaries = AiSummaryProvider(ai, events, settings)..startAutoSchedule();

  runApp(StatisApp(
    settings: settings,
    events: events,
    summaries: summaries,
  ));
}

class StatisApp extends StatelessWidget {
  const StatisApp({
    super.key,
    required this.settings,
    required this.events,
    required this.summaries,
  });

  final SettingsProvider settings;
  final EventsProvider events;
  final AiSummaryProvider summaries;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: events),
        ChangeNotifierProvider.value(value: summaries),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, s, _) {
          final scheme = ColorScheme.fromSeed(
            seedColor: s.themeColor,
            brightness: Brightness.light,
          );
          return MaterialApp(
            title: 'Statis',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: scheme,
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.transparent,
            ),
            home: const _Backdrop(child: MainWindow()),
          );
        },
      ),
    );
  }
}

/// 窗口背景层：按个性化设置渲染纯色 / 图片背景，供毛玻璃卡片模糊采样。
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    Widget? bg;
    if (s.bgKind == BgKind.color) {
      final value = int.tryParse(s.bgValue);
      if (value != null) {
        bg = ColoredBox(color: Color(value));
      }
    } else if (s.bgKind == BgKind.image && s.bgImageExists) {
      bg = Image.file(
        File(s.bgValue),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    // 默认背景：主题色柔和渐变。
    bg ??= Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            s.themeColor.withValues(alpha: 0.16),
            Theme.of(context).colorScheme.surface,
            s.themeColor.withValues(alpha: 0.10),
          ],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        bg,
        if (s.bgKind == BgKind.image && s.bgBlur > 0)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: s.bgBlur, sigmaY: s.bgBlur),
            child: const SizedBox.expand(),
          ),
        child,
      ],
    );
  }
}
