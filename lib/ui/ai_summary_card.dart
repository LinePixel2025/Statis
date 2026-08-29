import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../ui/glass_card.dart';

/// 渲染 AI 总结文本（Markdown -> 简洁样式）。
class AiSummaryCard extends StatelessWidget {
  const AiSummaryCard({
    super.key,
    this.title,
    required this.text,
    this.trailing,
  });

  final String? title;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle =
        theme.textTheme.bodyMedium!.copyWith(height: 1.45);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(title ?? 'AI 总结',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          MarkdownWidget(
            data: text,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            config: MarkdownConfig(configs: [
              PConfig(textStyle: bodyStyle),
              H1Config(
                  style: theme.textTheme.titleMedium!
                      .copyWith(fontWeight: FontWeight.w700)),
              H2Config(
                  style: theme.textTheme.titleMedium!
                      .copyWith(fontWeight: FontWeight.w700)),
              H3Config(style: theme.textTheme.titleSmall!),
            ]),
          ),
        ],
      ),
    );
  }
}
