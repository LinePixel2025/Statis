# Statis

<p align="center">
  <img src="assets/icon/app_icon.png" width="96" alt="Statis icon">
</p>

**Statis** 是一款跨平台统计器软件：添加一件会重复做的事情，每做一次就手动记录一次，应用会记录每次发生的时间，并据此生成热力图与 AI 总结。

## 功能

- **事件管理**：添加事件（名称 + 分类），主界面展示所有事件卡片
- **一键记录**：点击记录按钮，填写事件发生时间与备注
- **热力图**：基于事件历史记录绘制 365 天热力图（GitHub 风格）
- **AI 总结**：
  - 支持 OpenAI 兼容接口（OpenAI / DeepSeek / Moonshot / 通义 / 智谱等），填入 Base URL、API Key、模型名即可
  - 为开启 AI 的事件定期生成总结（发生频率、趋势），也可手动生成
  - 关键词可注入提示词，让总结围绕你关心的角度展开
  - 主界面显示全局简略总结
- **个性化**：毛玻璃卡片、可更换主题色与界面背景

## 平台

| 平台 | 状态 |
| --- | --- |
| Windows | ✅ 已支持 |
| 鸿蒙 HarmonyOS | 🚧 后期目标（Flutter-OpenHarmony） |
| 云端同步 | 🚧 后期目标 |

## 下载

前往 [Releases](https://github.com/LinePixel2025/Statis/releases) 下载：

- `Statis-Setup-1.0.1.exe` — 安装包
- `Statis-1.0.1-portable.zip` — 免安装便携版

## 从源码构建

需要 Flutter stable（含 Windows 桌面支持）与 Visual Studio 生成工具（含 C++ 桌面开发负载）。

```powershell
flutter pub get
flutter build windows --release
```

产物位于 `build\windows\x64\runner\Release\`。

## 数据位置

数据保存在本地：`%APPDATA%\Statis\statis.db`（SQLite），不出本机。AI 总结仅在生成时调用你自己配置的大模型服务。
