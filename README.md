# 模型余额手机 App（model_balance_app）

使用 Flutter 开发的手机端应用，支持 Android / iOS，后续可扩展 Windows 桌面与 Web。

## 功能

- **余额实时查询**：DeepSeek 官方（`user/balance`）、OpenAI 官方
  （`credit_grants`）、OpenAI 兼容中转渠道（one-api / new-api 类，
  `api/user/status`，quota 自动换算）
- **自动刷新**：默认每 30 秒刷新一次，支持下拉与按钮手动刷新
- **Token 用量记录**：手动记录输入（命中缓存 / 未命中缓存）与输出 Token 及费用，
  本地汇总统计；「用量」页提供按天柱状图（金额 / Token 可切换）与
  Token 构成扇形图（输入命中缓存 / 未命中缓存 / 输出）
- **余额快照**：每次成功查询自动写入本地 SQLite，与桌面版表结构一致
- **账户管理**：在 App 内添加 / 编辑 / 删除账户，API Key 保存在系统安全存储
  （Android Keystore / iOS Keychain），不写进明文文件、不上传服务器
- **应用内更新**：启动时自动检查、设置页可手动检查 GitHub Release 新版本，
  一键下载并唤起系统安装器，无需手动重新下载 APK


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
└── widget_test.dart          # 首页冒烟测试
```

## 环境要求

- Flutter 3.24+（Dart 3.5+）
- Android 构建：Android Studio / Android SDK（最低 API 23）
- iOS 构建：macOS + Xcode

## 当前状态（2026-08-07）

- Flutter 3.44.8（Dart 3.12.2）已安装于 `D:\flutter\flutter`，使用中国镜像
  （`pub.flutter-io.cn` / `storage.flutter-io.cn`）完成初始化
- `flutter create` 已生成 android / ios 平台工程
- `flutter analyze` 零问题；`flutter test` 7 个测试全部通过
- Android SDK 36.1.0 已安装于 `D:\Android\Sdk`（Android 36 平台 + build-tools）
- release APK 已打包：`build/app/outputs/flutter-apk/app-release.apk`（约 48.7MB，
  默认使用 debug 签名，可直接安装到手机）
- 2026-08-07 修复发布版网络权限（AndroidManifest 增加 INTERNET），已重新打包；
  应用名改为「模型余额」
- 2026-08-07 新增用量图表：每日柱状图（金额 / Token 切换）+ Token 构成扇形图，
  输入 Token 拆分命中 / 未命中缓存；已重新打包
- 2026-08-07 新增应用内更新（v0.2.0）：检查 GitHub Release → 下载 APK → 系统安装器安装
- 2026-08-07 更新提示增强（v0.2.1）：弹窗显示更新功能说明与更新包大小，下载进度显示已下载/总量
- 2026-08-07 稳定性优化（v0.2.2）：修复更新下载流程 bug（进度实时显示）、APK 下载后 SHA256 校验、
  正式签名（keystore）、按币种汇总余额、用量记录可编辑/删除、后台自动暂停刷新
- 2026-08-07 v0.2.3：更新安装完成后自动清理下载的临时 APK，不残留占用空间
- 2026-08-07 v0.2.4：启动时兜底清理残留临时包；更新源支持简单 version.json 格式
  （version/url/size/notes/sha256，缓解 GitHub API 限流）；保存更新源异常处理与地址格式校验
- 2026-08-07 v0.2.5：新增余额趋势折线图（近 30 天，多账户可切换）；余额自动刷新间隔可调
  （15/30/60/120 秒，持久化）
- 2026-08-07 v0.2.6：修复更新检查/弹窗无互斥导致的重复弹窗问题（连续触发只弹一次）

## 正式签名说明

- 签名文件：`android/app/upload-keystore.jks`（别名 upload），密码在
  `android/key.properties`——两者都已加入 .gitignore，不会提交到 GitHub。
- **务必备份 keystore 与密码**（复制到 U 盘/网盘），丢失后无法再升级覆盖安装。
- 缺少 key.properties 时构建会自动回退到 debug 签名（仅限本地调试）。

## 发布更新流程

1. 修改 `pubspec.yaml` 的 `version`（如 0.2.1+3），功能/修复说明写进 commit。
2. 本地验证：`flutter analyze` + `flutter test`，然后 `flutter build apk`。
3. 在 GitHub 仓库创建 Release：tag 用 `vX.Y.Z`（与 pubspec version 一致），
   上传 `app-release.apk` 作为资产，更新说明写在 Release 描述里。
4. 用户打开 App 会自动检测到新版本并提示更新；也可在「设置 → 版本更新」手动检查。

更新源默认为 GitHub Releases API（见 `lib/services/update_service.dart` 的
`updateSourceUrl`），也可换成自建服务器返回相同 JSON 结构。

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

- 打包并签名 Android APK，实机验证
- 余额趋势图与低余额提醒
- 与桌面版数据同步（可选，需后端）

## 相关项目（备注）

本 App 是桌面版「模型余额获取」（`D:\codexProject\模型余额`）的手机端实现，为独立项目。业务逻辑对应关系：

| 桌面版（Python） | 手机版（Dart） |
| --- | --- |
| `providers/*.py` | `lib/services/providers/*.dart` |
| `fetcher.py` | `lib/services/balance_service.dart` |
| `config.json` + `.env` | 账户配置与 Key 存入系统安全存储 |
| `storage.py`（SQLite） | `lib/services/storage_service.dart`（sqflite） |
| `app.py`（Tkinter） | `lib/screens/*`（Material 3） |

作为子项目，本目录只保留这一份 README.md；项目的开发进度文档
（memory.md / summary.md / todo.md）由父项目 `D:\codexProject\模型余额`
统一维护，涉及本项目的进度与约定请查看父项目的对应文档。
