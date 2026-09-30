# BigBigMouse

<img src="Resources/AppIcon.png" width="96" alt="BigBigMouse 应用图标">

一个只做鼠标滚轮反转的 macOS 菜单栏小工具。普通蓝牙鼠标的上下滚动反向，触控板保持原来的方向。

Swift + AppKit 原生应用，无第三方运行时或依赖。兼容目标为搭载 Apple M 系列芯片、运行 macOS 13 及以上系统的 Mac；构建需要 Swift 6.0 或更新版本。通用安装包也包含 Intel 架构。

Apple 芯片使用同一个原生 ARM64 版本，不按 M1、M2 等型号分别发布。系统最低版本与芯片架构是两个独立条件；旧系统需先升级。架构兼容不代表所有鼠标、所有系统版本均已实测，实际验证范围见 [验证记录](docs/VERIFICATION.md)。

## 安装与使用

1. 双击 `BigBigMouse-0.1.2-arm64.dmg`（Apple 芯片 Mac），或 `BigBigMouse-0.1.2-universal.dmg`（Apple 芯片与 Intel Mac）。
2. 将 **BigBigMouse.app** 拖到安装磁盘中 **Applications（应用程序）** 文件夹。
3. 从「应用程序」打开 BigBigMouse，再推出安装磁盘。不要直接从 DMG 里运行，否则权限可能关联到临时路径。
4. 按首次启动引导，到「系统设置 → 隐私与安全性 → 辅助功能」允许 BigBigMouse。如果列表中没有它，点「＋」添加安装在「应用程序」里的应用。
5. 检测到授权后会启用。如果仍在等待，点菜单里的「已授权但仍未生效…」重新打开应用；详细步骤见 [授权故障排查](docs/TROUBLESHOOTING.md)。点击菜单栏鼠标图标，可切换「启用鼠标滚轮反转」或退出。

实心鼠标图标表示正在反转，空心表示已关闭，感叹号表示尚未获得权限或未能启动。开关会被记住；无 Dock 图标，无开机启动功能。关闭或退出会移除滚动拦截，不修改系统设置。

请将 macOS 的「自然滚动」保持在你习惯的触控板方向。这个应用在系统现有方向上反转鼠标，而不是强制设定某个绝对方向。

### 本地开发版与公开分发

默认生成的安装包仅做 ad-hoc 本地签名，**尚未经过 Apple Developer ID 签名与公证**。不能把它当作已经可以无阻碍公开分发的正式版本。

从浏览器下载后，macOS 可能阻止首次打开。如果你确认来源可信，尝试打开一次后，在「系统设置 → 隐私与安全性」中选择「仍要打开」。无需关闭 Gatekeeper 或删除隔离属性。参见 [Apple 的首次打开说明](https://support.apple.com/102445)。

为了让下一个用户获得正常的浏览器下载安装体验，应使用自己的 Apple Developer ID Application 证书签名并完成公证，见下面的发布步骤。辅助功能授权仍需要用户本人完成。

### 兼容范围

- 第一版针对普通蓝牙滚轮鼠标，不需要蓝牙配对权限，配对由 macOS 完成。
- 程序依据滚动事件格式识别普通滚轮与触控板，不读取设备名称或蓝牙地址，也没有仅允许蓝牙的过滤器；同类 USB 滚轮事件也会自然适用。
- 不反转水平滚动，不改变鼠标移动、点击、加速度或触控板手势。
- 触控板连续滚动、惯性滚动和带手势阶段的事件直接原样通过。
- Magic Mouse、高精度平滑滚动鼠标及把滚轮转成连续事件的驱动不保证兼容。程序宁可保留这类连续滚动，也不把触控板误当作鼠标。
- 使用时请退出其他滚动方向修改软件，避免重复反转。

## 本地开发

```sh
bash scripts/test.sh
bash scripts/build.sh
open -n dist/0.1.2/BigBigMouse.app --args --allow-development-location
```

普通安装应从「应用程序」运行。上面的 `--allow-development-location` 仅用于开发调试，允许从构建目录启动；请先退出已安装的副本，避免重复运行和授权混淆。调试副本的权限以菜单所显示的实际位置为准。

打包拖拽安装的 DMG：

```sh
bash scripts/package-dmg.sh
# 同时包含 Apple 芯片与 Intel 架构：
bash scripts/package-dmg.sh --universal
```

应用构建产物在 `dist/<版本号>/`，DMG 在 `dist/`，编译缓存在 `.build/`，均已被 Git 忽略。按版本存放应用可避免新版本构建覆盖旧版本运行中的副本。DMG 包含应用、指向 `/Applications` 的文件夹快捷方式和中文安装说明；同时生成 SHA-256 校验文件。

本地 Git 已初始化为 `main`，没有创建提交、配置远程或推送。检查后可以自行执行：

```sh
git add .
git commit -m "Add minimal macOS mouse scroll reverser"
```

### 正式发布

在钥匙串中安装自己的 Developer ID Application 证书，然后构建：

```sh
SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
  bash scripts/package-dmg.sh --universal
```

脚本会对应用启用 Hardened Runtime 并签名，对 DMG 也进行签名。随后使用已配置的钥匙串公证凭据提交最终 DMG：

```sh
xcrun notarytool submit dist/BigBigMouse-0.1.2-universal.dmg \
  --keychain-profile BigBigMouse-notary --wait
# 仅在返回 Accepted 后继续：
xcrun stapler staple dist/BigBigMouse-0.1.2-universal.dmg
xcrun stapler validate dist/BigBigMouse-0.1.2-universal.dmg
spctl --assess --type open --context context:primary-signature \
  --verbose dist/BigBigMouse-0.1.2-universal.dmg
(cd dist && shasum -a 256 BigBigMouse-0.1.2-universal.dmg \
  > BigBigMouse-0.1.2-universal.dmg.sha256)
```

发布前还要将此最终 DMG 从浏览器下载到一台干净的 Mac，完成拖拽安装、首次启动和授权验收。公证会上传产物到 Apple；本项目未执行上传。参考 [Apple 公证文档](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)。

### 开源发布准备

- 已采用 [MIT 许可证](LICENSE)，从 0.1.2 起随应用和 DMG 一同打包。
- 将源码提交到自己的公开 GitHub 仓库，创建版本标签与 Release；将 DMG 和同名 `.sha256` 文件作为 Release 附件，用户无需自行编译。
- 为获得正常的首次下载打开体验，按上面的步骤完成 Developer ID 签名和公证。源码开源不要求先完成签名；本地开发包的下载限制应如实标明。
- 在其他 Apple 芯片 Mac 与较旧的支持系统上补充实测，记录系统版本、鼠标型号和连接方式。已知不兼容范围继续公开列出。

应用主图标由仓库内 `scripts/make-icon.swift` 的原创几何路径绘制，未把 Apple SF Symbols 导出为应用品牌图标。菜单栏继续在运行时使用系统图标。

本版可用于 GitHub Release 的说明见 [0.1.2 发布说明](docs/RELEASE_0.1.2.md)。

### 验证

自动化测试使用真实 `CGEvent` 对象，覆盖普通滚轮的行、像素和小数增量反转，水平滚动和修饰键保留，触控板与惯性事件逐字节不变，关闭状态，以及权限授予、撤销和启动失败恢复。测试不向系统注入滚动，也不需要辅助功能权限。

`bash scripts/test.sh` 还检查安装目录、路径伪装、重复副本判断和无效重启参数。要验证实际进程交接，可运行 `bash scripts/test-lifecycle.sh`：它使用独立 Bundle ID 的临时测试应用执行一次重新打开，不创建滚动监听、不请求权限，结束后清理测试进程和临时应用。

真实硬件验收请按 [docs/MANUAL_TESTS.md](docs/MANUAL_TESTS.md) 执行。自动化事件测试不能代替你的蓝牙鼠标、实际触控板及其他 Mac 系统版本的验收。

## 更新与卸载

更新：先从菜单栏退出旧版，拖入新版并替换。本地 ad-hoc 签名随构建变化；若辅助功能权限失效，在权限列表中移除旧条目，再添加安装后的新版。

卸载：从菜单栏退出，将「应用程序」中的 BigBigMouse 移到废纸篓即可。没有后台服务、登录项或网络请求，不记录滚动事件。用户偏好中仅保留开关与首次引导状态。

## 许可证

本项目采用 [MIT License](LICENSE)，版权归 Yanze Jiang 所有。允许使用、修改、分发和商业使用；分发时需保留版权声明及许可证文本。软件按现状提供，不附带担保，具体以许可证全文为准。
