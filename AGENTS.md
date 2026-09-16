# AGENTS.md · AI Agent 开发与发布工作流规范

本文件是为所有参与本项目的 AI 编码助手（AI Agents）提供的强制性工程规范与开发准则。在进行任何代码修改、功能新增、问题修复、打包或推送发布时，必须严格遵守以下规则。

---

## 1. 项目技术栈与基本架构

- **运行平台**：macOS 14.0+ (Apple Silicon / Intel)
- **开发语言与环境**：Swift 5.10+ / Swift 6.x，Xcode Command Line Tools
- **UI & 渲染架构**：纯原生 SwiftUI + AppKit + CoreGraphics / CoreText / PDFKit，**零第三方外部依赖**
- **工程形态**：SwiftPM 标准包 (`Package.swift`)，通过脚本打包为标准的 macOS `.app` 与 `.dmg` 镜像

---

## 2. 版本号与发布规范（强制遵守）

### 2.1 纯净版本号原则（Zero Bracket Rule）
- **核心要求**：所有向用户呈现的版本号，**一律使用标准的三段式纯版本号（例如 `1.0.1` 或 `版本 1.0.1`），严禁出现任何形式的构建号括号（例如严禁 `1.0.1 (3)` 或 `1.0.1 (build 3)`）**。
- **关于面板规范**：
  - 在 `PPTToolsApp.swift` 的标准关于窗口中，必须显式设置 `.version: ""`，`.applicationVersion: version`，杜绝系统自动追加括号。
- **Info.plist 配置**：
  - `CFBundleShortVersionString` 与 `CFBundleVersion` 必须始终保持完全一致的纯三段版本字符串（如均为 `1.0.1`）。

### 2.2 版本号递增规则 (Semantic Versioning 2.0.0)
版本号格式：`MAJOR.MINOR.PATCH`（项目起始基线版本为 `1.0.1`）：
1. **MAJOR (主版本号)**：重大架构革新、界面彻底重构、不兼容的文稿排版颠覆性变动。
2. **MINOR (次版本号)**：新增重要业务功能（如全新画板模板、新导入导出格式、关键设置功能）。
3. **PATCH (修订版本号)**：缺陷修复（Bugfix）、算法精度微调（如预估大小优化）、界面细节文案微调、防闪退与打包脚本维护。每次修改均需递增 PATCH。

### 2.3 每次修改发布同步检查清单 (Release Checklist)
当修改了应用内容并准备发布时，必须同步更新以下位置：
1. `scripts/build-app.sh`：
   ```xml
   <key>CFBundleShortVersionString</key><string>1.0.x</string>
   <key>CFBundleVersion</key><string>1.0.x</string>
   ```
2. `Sources/PPTTools/Services/UpdateManager.swift`：
   ```swift
   @Published public var currentVersion: String = "1.0.x"
   ```
3. 运行构建与打包：
   ```sh
   ./scripts/build-dmg.sh
   ```
4. 验证 DMG 命名与 Info.plist：
   ```sh
   /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" build/有用工具.app/Contents/Info.plist
   /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" build/有用工具.app/Contents/Info.plist
   ```

---

## 3. 标准构建、测试与运行命令

Agent 执行终端操作时，统一使用以下标准化命令：

```sh
# 1. 运行全部单元测试（隔离模块缓存）
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache" \
swift test --disable-sandbox

# 2. 编译并构建 Release 应用 (.app)
./scripts/build-app.sh

# 3. 一键打包高压缩比 DMG 镜像
./scripts/build-dmg.sh

# 4. 本地启动应用进行验证
build/有用工具.app/Contents/MacOS/PPTTools
```

---

## 4. 关键避坑与架构准则

### 4.1 资源加载与防闪退机制
- **SwiftPM Bundle.module 风险**：
  SwiftPM 为 executable 自动生成的 `Bundle.module` 如果找不到 `PPTTools_PPTTools.bundle`，会直接调用 `fatalError` 导致应用崩溃闪退。
- **规则**：
  1. `scripts/build-app.sh` 必须自动将编译产物中的 `PPTTools_PPTTools.bundle` 复制进 `$app/Contents/Resources/`。
  2. 源码（如 `ImageEngine.loadBackgroundImage`）必须**优先从 `Bundle.main` 和 `Contents/Resources` 短路加载**，绝不允许无条件依赖 `Bundle.module`。

### 4.2 空状态与失焦界面交互
- **禁止使用 ContentUnavailableView 的 actions 槽位**：
  macOS 14 的 `ContentUnavailableView` 在窗口失去焦点（用户点击其他应用时）会底层自动将 `actions` 内容隐藏或淡出，导致操作按钮消失。
- **禁止依赖系统 borderedProminent 按钮在失焦时的显示**：
  macOS 系统会将非活动窗口的 `borderedProminent` 按钮材质强制褪色（在浅色模式下退化为纯白/透明底，导致按钮隐形）。
- **规则**：
  所有主界面的空状态导入引导，统一使用常驻型的 `VStack` 与自定义纯 SwiftUI 按钮样式（如 `EmptyStatePrimaryButtonStyle`），确保在任何激活、失焦、分屏状态下按钮始终清晰可见、永不隐形。

### 4.3 文件体积预估规范
- 必须根据用户选定的导出 DPI（72 / 144 / 300）真实换算渲染像素：`ceil(w * dpi/72) * ceil(h * dpi/72)`。
- 长图因属于多幻灯片拼接画面，信息熵高，PNG 系数约为 `0.945 BPP`，JPEG 约为 `0.30 BPP`。
- 展示给用户的体积字符串必须使用 macOS 原生 `ByteCountFormatter(.file)`，确保与 macOS 访达（Finder）显示的十进制大小（如 `7.1 MB`）100% 对齐。

### 4.4 生产发布代码纯洁性
- 正式发布代码中严禁包含任何内部测试用快捷按钮（如 `测试：查看新版本弹窗…`），保持产品界面的简洁专业。

---

## 5. 推送与 GitHub Release 发布标准流程（强制执行）

**核心指令绑定**：每次用户下达**“推送”、“推送到github”、“发布版本”**等指令时，AI Agent 必须严格、依次执行以下完整工作流，缺一不可：

1. **测试与质量验证**：
   运行全部单元测试（`swift test --disable-sandbox`），确保所有测试用例 100% 通过。
2. **校验并更新版本号**：
   确认 `build-app.sh` 与 `UpdateManager.swift` 中的版本号一致（符合纯三段规则 `vX.Y.Z`），若有修改内容需递增版本。
3. **打包最新 DMG 安装镜像**：
   运行 `./scripts/build-dmg.sh`，生成最新命名的 `build/有用工具-v<VERSION>.dmg`。
4. **Git 提交代码**：
   ```sh
   git add .
   git commit -m "feat/fix/chore: <清晰描述本次改动内容>"
   ```
5. **打上 Git 对应版本标签 (Tag)**：
   ```sh
   git tag -a v<VERSION> -m "Release v<VERSION>"
   ```
6. **推送到 GitHub 远程仓库**：
   ```sh
   git push origin main --tags
   ```
7. **发布 GitHub Release 并上传 DMG 安装包**：
   通过 GitHub CLI (`gh`) 创建 Release 并附加 DMG 镜像：
   ```sh
   gh release create v<VERSION> \
       "build/有用工具-v<VERSION>.dmg" \
       --title "v<VERSION> - <本次发布主题>" \
       --notes "<详细更新日志列表>"
   ```
8. **验证交付产物**：
   确认 GitHub Release 页面发布成功，DMG 安装包资产链接有效，并向用户提供完整的 Release 链接和校验信息。
