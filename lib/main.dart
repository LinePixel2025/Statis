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
import 'ui/github_style.dart';
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
          // GitHub 浅色为固定基本面；primary 仍取用户自定义主题色作强调。
          final scheme = ColorScheme.light(
            primary: s.themeColor,
            onPrimary: Colors.white,
            surface: GithubStyle.surface,
            onSurface: GithubStyle.text,
            onSurfaceVariant: GithubStyle.textMuted,
            outline: GithubStyle.border,
            outlineVariant: GithubStyle.borderSubtle,
          );
          return MaterialApp(
            title: 'Statis',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: scheme,
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.transparent,
              // 统一文本与组件着色，正文走 GitHub 深色。
              textTheme: ThemeData.light().textTheme.apply(
                    bodyColor: GithubStyle.text,
                    displayColor: GithubStyle.text,
                  ),
            ),
            home: const _Backdrop(child: MainWindow()),
          );
        },
      ),
    );
  }
}

/// 窗口背景层：按个性化设置渲染纯色 / 图片背景；默认用 GitHub 画布底色。
/// GitHub 扁平风格下不再需要亮度计算与自动反色，仅保留背景渲染与图片模糊。
class _Backdrop extends StatefulWidget {
  const _Backdrop({required this.child});

  final Widget child;

  @override
  State<_Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<_Backdrop> {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();

    Widget? bg;
    if (s.bgKind == BgKind.color) {
      final value = int.tryParse(s.bgValue);
      if (value != null) bg = ColoredBox(color: Color(value));
    } else if (s.bgKind == BgKind.image && s.bgImageExists) {
      bg = Image.file(
        File(s.bgValue),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    // 默认背景：GitHub 画布底色（纯色，无渐变）。
    bg ??= const ColoredBox(color: GithubStyle.canvas);

    return Stack(
      fit: StackFit.expand,
      children: [
        bg,
        if (s.bgKind == BgKind.image && s.bgBlur > 0)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: s.bgBlur, sigmaY: s.bgBlur),
            child: const SizedBox.expand(),
          ),
        widget.child,
      ],
    );
  }
}
