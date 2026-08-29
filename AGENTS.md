# Statis 开发规范（AGENTS.md）

跨平台统计器：记录重复事件的发生时间，生成热力图与 AI 总结。

## 语言与风格

- 回复与代码注释使用简体中文；标识符、类名、文件名使用英文
- 提交信息格式：`feat:|fix:|chore:|docs: 中文描述`，每个功能一个 commit

## 技术栈与命令

- Flutter stable（本机 `D:\flutter`，已加入 PATH；镜像 `PUB_HOSTED_URL`/`FLUTTER_STORAGE_BASE_URL` 已设为 flutter-io.cn）
- 状态管理 provider；存储 sqflite_common_ffi（SQLite）；AI 走 OpenAI 兼容 chat/completions

```powershell
flutter analyze                # 静态检查（提交前必须无 issue）
flutter build windows --release
flutter test
```

构建产物：`build\windows\x64\runner\Release\`

## 架构

```
lib/
  main.dart                 # 组装：窗口初始化、Provider 注入、背景层 _Backdrop
  models/models.dart        # Event / EventRecord
  services/
    database_service.dart   # SQLite（%APPDATA%/Statis/statis.db）
    ai_service.dart         # OpenAI 兼容客户端 + 提示词构建
    ai_summary_provider.dart# 总结缓存 + 定期调度（每小时检查周期过期）
  providers/
    events_provider.dart    # 事件/记录状态与统计辅助
    settings_provider.dart  # 主题色/背景/AI 配置/总结周期（SharedPreferences）
  ui/
    main_window.dart        # 顶栏（statis + 设置 + 自绘窗口按钮）+ 两板块
    event_card.dart         # 事件卡片（记录弹窗、热力图、AI 摘要）
    heatmap.dart            # CustomPainter 365 天热力图
    ai_summary_card.dart    # Markdown 渲染总结
    settings_dialog.dart    # AI / 个性化 两选项卡
    glass_card.dart         # BackdropFilter 毛玻璃卡片
```

## 关键约定

- 数据库在 `onConfigure` 中开启 `PRAGMA foreign_keys = ON`；删事件先删其 records
- 事件 AI 总结完成时写 `events.last_summary_at`；超过 `summary_days` 天自动重新生成
- 窗口使用 `TitleBarStyle.hidden`，顶栏右侧自绘最小化/最大化/关闭按钮，`DragToMoveArea` 提供拖拽
- 主题色变化通过 `ColorScheme.fromSeed` 全局生效；热力图颜色跟随主题色

## 打包与发布

- Inno Setup：`installer.iss`，ISCC 位于 `%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`
- 便携版：Release 目录整体打包 zip（排除 `data` 之外的临时文件无需处理）
- 发布流程：tag `v1.0.0` → GitHub Release 上传 `Statis-Setup-<ver>.exe` 与 `Statis-<ver>-portable.zip`

## 平台规划

- Windows 已完成；鸿蒙（Flutter-OpenHarmony）与云端同步为后期目标，勿在当前阶段引入平台相关代码到共享层
