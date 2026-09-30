# 本地验证记录

## 0.1.2：安装与授权恢复

- `bash scripts/test.sh`：18/18 项通过，包含原有滚动与权限状态检查，以及安装目录、路径伪装、重复副本和重启参数检查。
- `bash scripts/test-lifecycle.sh`：通过独立临时测试应用调用生产代码的重新打开流程。实际记录为旧进程 ready → terminated → 新进程 launched → ready → terminated，未出现两个 ready 实例重叠。该测试没有创建滚动监听或请求辅助功能权限。
- arm64、x86_64 Release 编译通过；两种架构的最低 macOS 版本均为 13.0。
- 应用签名、DMG 完整性与 SHA-256 校验通过。
- 只读挂载确认版本为 0.1.2，Applications 快捷方式正确，应用内部和 DMG 根目录均包含与源码一致的 MIT 许可证；授权故障排查文本完整。
- plist、shell 脚本语法与 Git diff 空白检查通过。
- `/Applications/BigBigMouse.app` 仍是签名有效的 0.1.1，未替换、重启或重置用户正在使用的安装版。新版只交付到 `dist/`。
- 尚未完成 0.1.2 新提示的完整点击验收、真实硬件回归、多机型测试或 Developer ID 签名公证。自动化重启测试不代表已验证所有 macOS 授权缓存行为。

## 0.1.1：图标更新

- 用户反馈：0.1.0 已在自己的 Mac 上实际使用，功能表现良好。尚未按硬件验收清单逐项记录，不据此推断其他设备全部通过。
- 应用主图标改为原创黑白鼠标路径，256 像素预览已目视检查。菜单栏图标与滚动功能源码未变。
- 通用 Release 构建及 ad-hoc 签名完整性检查通过。
- `lipo` 确认含 arm64 和 x86_64；`vtool` 确认两种架构的最低 macOS 版本均为 13.0。
- DMG 校验和及只读挂载检查通过：版本 0.1.1、新图标、Applications 快捷方式和应用签名正确。
- 新应用位于 `dist/0.1.1/BigBigMouse.app`；未覆盖或退出用户正在运行的 `dist/BigBigMouse.app`。
- 本次没有修改滚动功能，沿用下列 0.1.0 的 13 项自动化检查结果。
- 后续用户遇到授权开关已开启但应用仍等待的问题。清理本应用的系统授权记录、重新安装并授权后，用户确认恢复正常；该组合操作的记录与边界见 [授权故障排查](TROUBLESHOOTING.md)。
- 尚未完成 Developer ID 签名、公证、多机型测试或公开发布。用户随后已选择 MIT 许可证，根目录 `LICENSE` 已添加；后续构建将其随应用和 DMG 打包，现有 0.1.1 安装包未重建。

## 0.1.0

验证日期：2026-09-30。

环境：Apple 芯片 Mac，macOS 26.6.2，Apple Swift 6.3.2，Command Line Tools。没有依赖完整 Xcode 或第三方库。

已通过：

- `bash scripts/test.sh`：13/13 项检查通过。
- Release 编译：arm64 与 x86_64 均成功；`lipo -archs` 确认最终应用含两个架构。
- `Info.plist` 格式检查与 shell 脚本语法检查。
- 应用 ad-hoc 签名完整性：`codesign --verify --deep --strict` 通过。
- 通用 DMG：生成成功，`hdiutil verify` 与 SHA-256 校验通过。
- DMG 只读挂载：确认含应用、指向 `/Applications` 的快捷方式、中文安装说明。
- 模拟拖拽复制到项目测试目录后，签名验证仍通过，二进制与构建产物逐字节一致，且保留两个架构。检查后已卸载映像。
- 应用启动命令被 macOS Launch Services 成功接受。
- 应用图标各 PNG 尺寸经过检查，256 像素图标经过目视检查。

尚未验证或执行：

- 界面自动检查服务连续超时，未完成首次引导和菜单栏交互的视觉验收。
- 未代替用户授予辅助功能权限，未验证真实蓝牙滚轮、触控板和唤醒后的行为。
- 未在 Intel 硬件或 macOS 13–15 上运行；通用编译不等于所有系统已实测。
- 未进行 Developer ID 签名、公证、上传、Git commit 或 push。

实机验收步骤见 [MANUAL_TESTS.md](MANUAL_TESTS.md)。
