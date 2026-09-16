# PPTTools · 版本号管理规范 (Version Specification)

本项目遵循严格的 **语义化版本规范 (Semantic Versioning 2.0.0)** 与 **macOS 原生纯净展示原则**。

---

## 1. 核心原则与展示规范

### 1.1 纯净版本号原则（禁止括号构建号）
- **规范**：所有面向用户呈现的位置（关于面板、更新弹窗、下载说明、DMG 卷标名），**统一采用纯净的三段式版本号**（例如 `版本 0.1.2` 或 `v0.1.2`）。
- **禁止**：严禁出现 macOS 原生默认的带括号内部构建号格式（例如 `0.1.2 (3)` 或 `0.1.2 (build 3)`）。
- **配置实现**：
  1. `Info.plist` 中的 `CFBundleShortVersionString` 与 `CFBundleVersion` 均统一填入三段式纯版本号（如 `0.1.2`）。
  2. 原生标准关于窗口调用 `orderFrontStandardAboutPanel` 时，显式将 `.version` 置空 (`""`)，`.applicationVersion` 设为三段式版本号，确保系统界面只呈现 `版本 0.1.2`。

---

## 2. 语义化版本号结构

版本号格式为：**`MAJOR.MINOR.PATCH`**（如 `0.1.2`）：

| 字段 | 名称 | 递增时机 | 示例 |
| :--- | :--- | :--- | :--- |
| **MAJOR** | 主版本号 | 重大架构升级、界面全面重构、不兼容的渲染/排版算法颠覆变动 | `1.0.0` |
| **MINOR** | 次版本号 | 新增主要业务功能（如全新画板模板、新导入导出格式、关键设置项） | `0.2.0` |
| **PATCH** | 修订版本号 | 缺陷修复（Bugfix）、算法精度微调（如预估大小优化）、界面文案微调、打包依赖修复 | `0.1.2` |

> [!NOTE]
> 在首个正式商用版发布前，主版本号保持为 `0`（如 `0.1.x`）。

---

## 3. 发布与同步清单 (Release Checklist)

发布新版本或修改代码内容后，必须按以下清单同步版本号：

- [ ] **1. 构建脚本 `scripts/build-app.sh`**：
  ```xml
  <key>CFBundleShortVersionString</key><string>1.0.1</string>
  <key>CFBundleVersion</key><string>1.0.1</string>
  ```
- [ ] **2. 更新管理服务 `Sources/PPTTools/Services/UpdateManager.swift`**：
  ```swift
  @Published public var currentVersion: String = "1.0.1"
  ```
- [ ] **3. 执行全量编译与打包**：
  ```sh
  ./scripts/build-dmg.sh
  ```
- [ ] **4. 验证生成的安装包与镜像名**：
  - 生成镜像：`build/有用工具-v1.0.1.dmg`
  - 校验版本号：
    ```sh
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" build/有用工具.app/Contents/Info.plist
    /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" build/有用工具.app/Contents/Info.plist
    ```
- [ ] **5. Git Tag 与 GitHub Release**：
  - Tag 规范：`v1.0.1`
  - Release Title：`v1.0.1 - <简述更新主题>`
  - 附件产物：`有用工具-v1.0.1.dmg`
