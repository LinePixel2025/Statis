import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';
import 'github_style.dart';

/// 设置弹窗：AI / 个性化 两个选项卡。
Future<void> showSettingsDialog(
    BuildContext context, SettingsProvider settings) {
  final baseUrlCtl = TextEditingController(text: settings.aiBaseUrl);
  final apiKeyCtl = TextEditingController(text: settings.aiApiKey);
  final modelCtl = TextEditingController(text: settings.aiModel);
  BgKind bgKind = settings.bgKind;
  String bgValue = settings.bgValue;
  double bgBlur = settings.bgBlur;
  int summaryDays = settings.summaryDays;
  Color themeColor = settings.themeColor;
  TrendKind trendKind = settings.trendKind;

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('设置',
              style: TextStyle(color: GithubStyle.text)),
          content: DefaultTabController(
            length: 2,
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TabBar(tabs: [Tab(text: 'AI'), Tab(text: '个性化')]),
                  Flexible(
                    child: TabBarView(
                      children: [
                        // ---- AI 选项卡 ----
                        ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          children: [
                            Text(
                              '兼容 OpenAI 接口（OpenAI / DeepSeek / 通义 / 智谱 / Moonshot 等），'
                              '填入对应服务商的 Base URL、API Key 与模型名即可。',
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: baseUrlCtl,
                              decoration: const InputDecoration(
                                labelText: 'Base URL',
                                hintText: 'https://api.deepseek.com/v1',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: apiKeyCtl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'API Key',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: modelCtl,
                              decoration: const InputDecoration(
                                labelText: '模型名',
                                hintText: 'deepseek-chat',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('总结周期：每 $summaryDays 天'),
                                Expanded(
                                  child: Slider(
                                    value: summaryDays.toDouble(),
                                    min: 1,
                                    max: 30,
                                    divisions: 29,
                                    label: '$summaryDays 天',
                                    onChanged: (v) =>
                                        setState(() => summaryDays = v.round()),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // ---- 个性化选项卡 ----
                        ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          children: [
                            Text('主题色', style: Theme.of(ctx).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              children: [
                                for (final c in SettingsProvider.presetColors)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => setState(() => themeColor = c),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: themeColor.toARGB32() == c.toARGB32()
                                              ? Theme.of(ctx)
                                                  .colorScheme
                                                  .onSurface
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: themeColor.toARGB32() == c.toARGB32()
                                          ? Icon(Icons.check,
                                              size: 18,
                                              color: ThemeData.estimateBrightnessForColor(c) == Brightness.dark
                                                  ? Colors.white
                                                  : Colors.black)
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text('趋势展示',
                                style: Theme.of(ctx).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            SegmentedButton<TrendKind>(
                              segments: const [
                                ButtonSegment(
                                    value: TrendKind.line,
                                    icon: Icon(Icons.show_chart, size: 16),
                                    label: Text('折线图')),
                                ButtonSegment(
                                    value: TrendKind.heatmap,
                                    icon: Icon(Icons.grid_view, size: 16),
                                    label: Text('热力图')),
                              ],
                              selected: {trendKind},
                              onSelectionChanged: (s) =>
                                  setState(() => trendKind = s.first),
                            ),
                            const SizedBox(height: 16),
                            Text('界面背景', style: Theme.of(ctx).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            SegmentedButton<BgKind>(
                              segments: const [
                                ButtonSegment(
                                    value: BgKind.none, label: Text('默认')),
                                ButtonSegment(
                                    value: BgKind.color, label: Text('纯色')),
                                ButtonSegment(
                                    value: BgKind.image, label: Text('图片')),
                              ],
                              selected: {bgKind},
                              onSelectionChanged: (s) =>
                                  setState(() => bgKind = s.first),
                            ),
                            if (bgKind == BgKind.color) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                children: [
                                  for (final c in [
                                    ...SettingsProvider.presetColors,
                                    const Color(0xFF1C1F26),
                                    const Color(0xFFF2F3F7),
                                  ])
                                    InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () =>
                                          setState(() => bgValue = c.toARGB32().toString()),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: c,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: bgValue == c.toARGB32().toString()
                                                ? Theme.of(ctx)
                                                    .colorScheme
                                                    .onSurface
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            if (bgKind == BgKind.image) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      bgValue.isEmpty ? '未选择图片' : bgValue,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(ctx).textTheme.bodySmall,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      const types = <XTypeGroup>[
                                        XTypeGroup(label: '图片', extensions: [
                                          'png', 'jpg', 'jpeg', 'webp', 'bmp'
                                        ]),
                                      ];
                                      final path = await openFile(
                                          acceptedTypeGroups: types);
                                      if (path != null) {
                                        setState(() => bgValue = path.path);
                                      }
                                    },
                                    child: const Text('选择图片…'),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('背景模糊：${bgBlur.round()}'),
                                Expanded(
                                  child: Slider(
                                    value: bgBlur,
                                    min: 0,
                                    max: 60,
                                    label: '${bgBlur.round()}',
                                    onChanged: (v) => setState(() => bgBlur = v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                settings.setAiConfig(baseUrlCtl.text, apiKeyCtl.text, modelCtl.text);
                settings.setSummaryDays(summaryDays);
                settings.setThemeColor(themeColor);
                settings.setTrendKind(trendKind);
                settings.setBackground(bgKind, bgValue, bgBlur);
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
    },
  );
}
