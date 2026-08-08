# 模型余额手机 App（model_balance_app）

使用 Flutter 开发的手机端应用，支持 Android / iOS，后续可扩展 Windows 桌面与 Web。

## 功能

- **余额实时查询**：DeepSeek 官方（`user/balance`）、OpenAI 官方
  （`credit_grants`）、OpenAI 兼容中转渠道（one-api / new-api 类，
  `api/user/status`，quota 自动换算）
- **自动刷新**：默认每 30 秒刷新一次，间隔可在设置页调整（15/30/60/120 秒，
  持久化）；App 进入后台自动暂停，回前台立即刷新；支持下拉与按钮手动刷新
- **余额趋势折线图**：首页展示各账户近 30 天余额变化，多账户可切换
- **Token 用量记录**：手动记录输入（命中缓存 / 未命中缓存）与输出 Token 及费用，
  本地汇总统计；「用量」页提供按天柱状图（金额 / Token 可切换）与
  Token 构成扇形图（输入命中缓存 / 未命中缓存 / 输出）；记录可编辑 / 删除；
  支持导入桌面端导出的 Codex 用量 JSON（粘贴或选文件）与局域网一键同步
  （同一 WiFi 下输入电脑 IP + 同步令牌直接拉取，均按 key 增量去重；
  令牌只用于读取用量，不涉及 API Key）
- **余额快照**：每次成功查询自动写入本地 SQLite，与桌面版表结构一致
- **账户管理**：在 App 内添加 / 编辑 / 删除账户，API Key 保存在系统安全存储
  （Android Keystore / iOS Keychain），不写进明文文件、不上传服务器
- **应用内更新**：启动时自动检查、设置页可手动检查 GitHub Release 新版本，
  一键下载（多线程分块加速 + 进度显示 + SHA256 校验）并唤起系统安装器，
  安装后自动清理临时包；更新源可配置（GitHub Releases 或自建 version.json）


## 目录结构

```text
lib/
├── main.dart                 # 入口
├── app.dart                  # MaterialApp + 底部导航
├── models/                   # Account / Balance / UsageRecord
├── services/
│   ├── providers/            # deepseek / openai / openai_compat 查询适配器
│   ├── balance_service.dart  # 余额聚合查询
│   ├── secure_config_store.dart  # API Key 安全存储
│   └── storage_service.dart  # SQLite 用量与快照
├── state/balance_state.dart  # 全局状态（Provider）
├── screens/                  # 余额 / 用量 / 设置 / 账户编辑
├── widgets/                  # 账户卡片、用量记录等组件
└── utils/formats.dart        # 金额与时间格式化
test/
├── parsers_test.dart         # 三家余额响应解析单测
├── usage_stats_test.dart     # 用量统计聚合测试
├── update_service_test.dart  # 更新源解析 / 版本比较 / SHA256 测试
├── balance_state_test.dart   # 状态层测试（按币种汇总 / 刷新间隔）
├── formats_test.dart         # 格式化工具测试
└── widget_test.dart          # 首页冒烟测试
```

## 环境要求

- Flutter 3.24+（Dart 3.5+）
- Android 构建：Android Studio / Android SDK（最低 API 23）
- iOS 构建：macOS + Xcode

## 当前状态

- 最新版本：**v0.2.8**（已发布 GitHub Release，正式签名 APK + SHA256 校验文件）
- `flutter analyze` 零问题；`flutter test` 25 个测试全部通过
- APK 产物：`build/app/outputs/flutter-apk/app-release.apk`（约 50.4MB，正式签名）
- 开发环境：Flutter 3.44.8 / Dart 3.12.2 / Android SDK 36.1.0，构建走中国镜像

## 版本历史

| 版本 | 主要内容 |
| --- | --- |
| v0.2.0 | 应用内更新：检查 GitHub Release → 下载 → 系统安装器安装 |
| v0.2.1 | 更新提示显示更新说明与更新包大小、下载进度 |
| v0.2.2 | 稳定性优化：更新下载流程修复、SHA256 校验、正式签名、按币种汇总、用量记录编辑/删除、后台暂停刷新 |
| v0.2.3 | 更新安装完成后自动清理临时 APK |
| v0.2.4 | 启动兜底清理临时包；更新源兼容 version.json；保存异常处理与格式校验 |
| v0.2.5 | 余额趋势折线图；自动刷新间隔可调（持久化） |
| v0.2.6 | 修复重复弹出更新窗口（检查互斥） |
| v0.2.7 | 更新下载加速：多线程分块下载（4 路并行，服务器不支持时自动回退） |
| v0.2.8 | 导入 Codex 用量 + 局域网一键同步（桌面 lan-sync 服务 → 手机端拉取，去重入库） |

## 正式签名说明

- 签名文件：`android/app/upload-keystore.jks`（别名 upload），密码在
  `android/key.properties`——两者都已加入 .gitignore，不会提交到 GitHub。
- **务必备份 keystore 与密码**（复制到 U 盘/网盘），丢失后无法再升级覆盖安装。
- 缺少 key.properties 时构建会自动回退到 debug 签名（仅限本地调试）。

## 发布更新流程

1. 修改 `pubspec.yaml` 的 `version`（如 0.2.1+3），功能/修复说明写进 commit。
2. 本地验证：`flutter analyze` + `flutter test`，然后 `flutter build apk`。
3. 在 GitHub 仓库创建 Release：tag 用 `vX.Y.Z`（与 pubspec version 一致），
   上传 `app-release.apk` 与 `app-release.apk.sha256` 作为资产，
   更新说明写在 Release 描述里。
4. 用户打开 App 会自动检测到新版本并提示更新；也可在「设置 → 版本更新」手动检查。

更新源默认为 GitHub Releases API（见 `lib/services/update_service.dart` 的
`updateSourceUrl`），可在「设置 → 更新源地址」修改；也可换成自建服务器返回
`{"version","url","size","notes","sha256"}` 结构的 version.json。

## 构建源配置（镜像）

本机网络直连 pub.dev / services.gradle.org 下载过慢或失败，因此本项目固定使用
一套中国镜像源（Flutter 与 Android 构建均生效）：

| 用途 | 镜像源 |
| --- | --- |
| Flutter / Dart 包 | `https://pub.flutter-io.cn`（PUB_HOSTED_URL） |
| Flutter 组件 | `https://storage.flutter-io.cn`（FLUTTER_STORAGE_BASE_URL） |
| Gradle 发行版 | `https://mirrors.cloud.tencent.com/gradle/`（见 `android/gradle/wrapper/gradle-wrapper.properties`） |
| Maven 依赖 | `https://maven.aliyun.com/repository/`（google / central / gradle-plugin，见 `android/settings.gradle.kts` 与 `android/build.gradle.kts`） |

如需切回官方源：还原 `gradle-wrapper.properties` 的 distributionUrl 为
`services.gradle.org`，并把 Gradle 配置中的镜像仓库改回 `google()` /
`mavenCentral()` 即可。

## 快速开始

```bash
flutter pub get
flutter run          # 连接手机或模拟器运行
flutter test         # 运行测试
flutter analyze      # 静态检查
flutter build apk    # 打 Android 安装包
```

## 使用说明

1. 打开 App，进入「设置」→「添加账户」。
2. 选择提供商：
   - `deepseek`：填 DeepSeek API Key（余额为 CNY）。
   - `openai`：填 OpenAI API Key（余额为 USD，部分 Key 可能无权限）。
   - `openai_compat`：填中转渠道 Key、`base_url`（如
     `https://your-relay.example.com`）与 quota 换算分母（one-api 默认 500000）。
3. 回到「余额」页，下拉或点刷新即可实时查询。
4. 「用量」页可手动记录 Token 使用情况。

## 安全说明

- API Key 只保存在手机系统安全存储中；卸载 App 会清除全部本地数据。
- 查询余额时 App 直接访问官方 / 中转接口，不经过第三方服务器。

## 下一步计划

- 低余额告警
- Token 用量自动采集（中转渠道用量接口，DeepSeek 官方无公开用量接口）
- 与桌面版数据同步（可选，需后端）
- iOS 构建验证（需 macOS 环境）

## 相关项目（备注）

本 App 是桌面版「模型余额获取」（`D:\codexProject\模型余额`）的手机端实现，为独立项目。业务逻辑对应关系：

| 桌面版（Python） | 手机版（Dart） |
| --- | --- |
| `providers/*.py` | `lib/services/providers/*.dart` |
| `fetcher.py` | `lib/services/balance_service.dart` |
| `config.json` + `.env` | 账户配置与 Key 存入系统安全存储 |
| `storage.py`（SQLite） | `lib/services/storage_service.dart`（sqflite） |
| `app.py`（Tkinter） | `lib/screens/*`（Material 3） |

作为独立项目，本目录维护完整四件套（README / memory / todo / summary），进度文档不并入父项目；端间关系说明见本 README「相关项目（备注）」段落。
