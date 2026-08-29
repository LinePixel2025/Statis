import 'package:flutter/material.dart';

import '../providers/events_provider.dart';

/// 添加事件弹窗：填写名称与分类（必填）。
Future<void> showAddEventDialog(BuildContext context, EventsProvider events) {
  final nameCtl = TextEditingController();
  final categoryCtl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('添加事件'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '事件名称',
                hintText: '例如：跑步、背单词、早睡',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请填写事件名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: categoryCtl,
              decoration: const InputDecoration(
                labelText: '分类',
                hintText: '例如：运动、学习、生活',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请填写分类' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              events.addEvent(nameCtl.text.trim(), categoryCtl.text.trim());
              Navigator.pop(ctx);
            }
          },
          child: const Text('添加'),
        ),
      ],
    ),
  );
}
