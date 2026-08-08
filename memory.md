# 项目目标

用户定义（不得修改方向）：

- 手机端实时查看模型 API 账户余额与 Token 用量
- 应用形态：Android / iOS 手机 App（Flutter）
- 用户无需手动重新下载安装包，支持应用内更新

# 当前状态

- 2026-08-08：v0.2.7 已发布（多线程分块下载加速）；余额查询 / 用量图表 / 余额趋势 / 应用内更新齐全
- `flutter analyze` 零问题；`flutter test` 25 个测试通过
- 正式签名 keystore 已配置并用于 Release 打包

# 技术方案

- Flutter 3.44.8（Dart 3.12.2）+ Provider + sqflite + flutter_secure_storage + fl_chart + http
- 余额查询：DeepSeek / OpenAI / openai_compat 适配器，多账户并发查询
- 存储：API Key 存系统安全存储（Keystore / Keychain）；用量记录与余额快照存本地 SQLite
- 用量可视化：每日柱状图（金额 / Token 切换）、Token 构成扇形图（命中缓存 / 未命中缓存 / 输出）、余额趋势折线图
- 应用内更新：更新源可配置（GitHub Releases API 或 version.json）；多线程分块下载 + SHA256 校验 + 系统安装器；安装后自动清理临时包
- 构建源：中国镜像（pub.flutter-io.cn / storage.flutter-io.cn / 腾讯 Gradle / 阿里云 Maven）

# 开发规范

- 遵循 software-development + flutter-development 技能，analyze / test 验收（详见项目 AGENTS.md）
- 上传 GitHub 前必须通过质量检查清单；不合规不推送
- 版本发布唯一入口：gh-release-publish 技能（先展示计划、用户授权后才执行）
- 文档同步：todo.md / memory.md / summary.md 与开发同步更新

# 已知问题

- DeepSeek 官方无公开用量接口，用量只能手动记录或靠代理采集
- github.com 直连不稳定，推送 / 下载需重试或换镜像
- iOS 端未构建验证（本机无 macOS）

# 下一步计划

1. 低余额告警
2. Token 用量自动采集（中转渠道用量接口）
3. 测试补强：下载逻辑 mock 单测、弹窗互斥测试、ListView.builder
4. 与桌面版数据同步（可选）
5. iOS 构建验证
