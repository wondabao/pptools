import Foundation
import AppKit
import Combine

// MARK: - 语义化版本号比对
public struct SemanticVersion: Comparable, Equatable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let raw: String

    public init(_ rawString: String) {
        self.raw = rawString
        var clean = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.lowercased().hasPrefix("v") {
            clean = String(clean.dropFirst())
        }
        let parts = clean.split(separator: ".").compactMap { Int($0) }
        self.major = parts.indices.contains(0) ? parts[0] : 0
        self.minor = parts.indices.contains(1) ? parts[1] : 0
        self.patch = parts.indices.contains(2) ? parts[2] : 0
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
}

// MARK: - GitHub Release 数据结构
public struct GitHubRelease: Codable, Equatable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String
    public let publishedAt: String?
    public let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }

    public var dmgAsset: GitHubReleaseAsset? {
        assets.first { $0.name.lowercased().hasSuffix(".dmg") }
    }
}

public struct GitHubReleaseAsset: Codable, Equatable {
    public let name: String
    public let browserDownloadUrl: String
    public let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

public enum UpdateAlertType: Identifiable {
    case upToDate(String)
    case error(String)

    public var id: String {
        switch self {
        case .upToDate(let v): return "upToDate_\(v)"
        case .error(let m): return "error_\(m)"
        }
    }
}

// MARK: - 更新管理器
@MainActor
public final class UpdateManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = UpdateManager()

    /// 仓库地址配置
    public let githubOwner = "wondabao"
    public let githubRepo = "pptools"

    @Published public var currentVersion: String = "1.2.0"
    @Published public var isChecking: Bool = false
    @Published public var hasNewVersion: Bool = false
    @Published public var latestRelease: GitHubRelease? = nil
    @Published public var showUpdateSheet: Bool = false
    @Published public var activeAlert: UpdateAlertType? = nil

    // 下载与准备状态
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadSpeedText: String = ""
    @Published public var downloadedDMGURL: URL? = nil
    @Published public var isExtracting: Bool = false
    @Published public var isReadyToRestart: Bool = false
    @Published public var stagedAppURL: URL? = nil
    @Published public var installStatusMessage: String = ""

    private var downloadTask: URLSessionDownloadTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    public override init() {
        super.init()
        if let bundleId = Bundle.main.bundleIdentifier, bundleId.contains("pptools"),
           let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !ver.isEmpty {
            self.currentVersion = ver
        }
    }

    /// 检查更新
    /// - Parameter manual: 是否为用户主动在菜单点击。主动点击时若已是最新会弹出提示。
    public func checkForUpdates(manual: Bool = false) {
        guard !isChecking else { return }
        isChecking = true

        let urlString = "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("PPTTools-App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "UpdateError", code: -1, userInfo: [NSLocalizedDescriptionKey: "网络响应异常"])
                }

                if httpResponse.statusCode == 404 {
                    // 尚未发布 Release
                    self.isChecking = false
                    if manual {
                        self.activeAlert = .upToDate(self.currentVersion)
                    }
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    throw NSError(domain: "UpdateError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "GitHub 请求失败 (状态码 \(httpResponse.statusCode))"])
                }

                let decoder = JSONDecoder()
                let release = try decoder.decode(GitHubRelease.self, from: data)

                self.latestRelease = release
                let latestVer = SemanticVersion(release.tagName)
                let currVer = SemanticVersion(self.currentVersion)

                self.isChecking = false

                if latestVer > currVer {
                    self.hasNewVersion = true
                    self.showUpdateSheet = true
                } else {
                    self.hasNewVersion = false
                    if manual {
                        self.activeAlert = .upToDate(self.currentVersion)
                    }
                }
            } catch {
                self.isChecking = false
                if manual {
                    self.activeAlert = .error(error.localizedDescription)
                }
            }
        }
    }

    /// 模拟测试：直接唤起新版本更新弹窗（用于快速测试交互）
    public func simulateUpdateForTesting() {
        self.latestRelease = GitHubRelease(
            tagName: "v1.1.1",
            name: "v1.1.1 - 自动重启更新体验测试",
            body: "- 支持下载完成后一键重启更新\n- 强化原生零依赖架构",
            htmlUrl: "https://github.com/wondabao/pptools/releases/tag/v1.1.0",
            publishedAt: "2026-09-16T11:30:00Z",
            assets: [
                GitHubReleaseAsset(
                    name: "有用工具-v1.0.1.dmg",
                    browserDownloadUrl: "https://github.com/wondabao/pptools/releases/download/v1.0.1/有用工具-v1.0.1.dmg",
                    size: 9646899
                )
            ]
        )
        self.hasNewVersion = true
        self.showUpdateSheet = true
    }

    /// 开始在线下载新版 DMG
    public func startDownload() {
        guard let release = latestRelease else { return }
        if let asset = release.dmgAsset, let downloadURL = URL(string: asset.browserDownloadUrl) {
            isDownloading = true
            isExtracting = false
            isReadyToRestart = false
            downloadProgress = 0.0
            installStatusMessage = "正在连接下载服务器…"
            downloadTask = urlSession.downloadTask(with: downloadURL)
            downloadTask?.resume()
        } else if let pageURL = URL(string: release.htmlUrl) {
            // 没有上传 dmg asset，直接打开浏览器发布页
            NSWorkspace.shared.open(pageURL)
            showUpdateSheet = false
        }
    }

    /// 取消下载
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        isExtracting = false
        isReadyToRestart = false
        downloadProgress = 0.0
        installStatusMessage = ""
    }

    /// 打开下载到的 DMG 进行手动安装
    public func openDownloadedDMG() {
        guard let dmgURL = downloadedDMGURL else { return }
        NSWorkspace.shared.open(dmgURL)
        installStatusMessage = "已打开安装镜像，请拖拽更新应用"
    }

    /// 在后台将下载的 DMG 挂载并提取 .app 到暂存区，以便随时一键重启完成更新
    public func prepareDownloadedUpdate(dmgURL: URL) async {
        isExtracting = true
        isReadyToRestart = false
        installStatusMessage = "下载完成，正在准备新版本…"

        let extractResult: Result<URL, Error> = await Task.detached(priority: .userInitiated) {
            do {
                // 1. 挂载 DMG
                let mountProcess = Process()
                mountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                mountProcess.arguments = ["attach", "-nobrowse", "-readonly", "-plist", dmgURL.path]
                let pipe = Pipe()
                mountProcess.standardOutput = pipe
                try mountProcess.run()
                mountProcess.waitUntilExit()

                guard mountProcess.terminationStatus == 0 else {
                    throw NSError(domain: "UpdateError", code: Int(mountProcess.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "挂载更新镜像失败"])
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                      let entities = plist["system-entities"] as? [[String: Any]] else {
                    throw NSError(domain: "UpdateError", code: -2, userInfo: [NSLocalizedDescriptionKey: "解析更新镜像结构失败"])
                }

                var mountPoint: String? = nil
                for entity in entities {
                    if let mp = entity["mount-point"] as? String {
                        mountPoint = mp
                        break
                    }
                }

                guard let finalMountPoint = mountPoint else {
                    throw NSError(domain: "UpdateError", code: -3, userInfo: [NSLocalizedDescriptionKey: "未找到镜像挂载卷"])
                }

                defer {
                    let detachProc = Process()
                    detachProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    detachProc.arguments = ["detach", finalMountPoint, "-force"]
                    try? detachProc.run()
                    detachProc.waitUntilExit()
                }

                // 2. 在挂载卷内查找 .app
                let mountURL = URL(fileURLWithPath: finalMountPoint)
                let contents = try FileManager.default.contentsOfDirectory(at: mountURL, includingPropertiesForKeys: nil)
                guard let appBundle = contents.first(where: { $0.pathExtension == "app" }) else {
                    throw NSError(domain: "UpdateError", code: -4, userInfo: [NSLocalizedDescriptionKey: "镜像内未找到应用程序包"])
                }

                // 3. 复制到暂存目录
                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
                let updateDir = appSupport.appendingPathComponent("com.wondabao.pptools/Updates", isDirectory: true)
                try FileManager.default.createDirectory(at: updateDir, withIntermediateDirectories: true)

                let stagedApp = updateDir.appendingPathComponent(appBundle.lastPathComponent)
                try? FileManager.default.removeItem(at: stagedApp)

                let dittoProc = Process()
                dittoProc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                dittoProc.arguments = [appBundle.path, stagedApp.path]
                try dittoProc.run()
                dittoProc.waitUntilExit()

                guard dittoProc.terminationStatus == 0 else {
                    throw NSError(domain: "UpdateError", code: Int(dittoProc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "解压新版本失败"])
                }

                // 4. 清理隔离属性，避免 Gatekeeper 拦截
                let xattrProc = Process()
                xattrProc.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                xattrProc.arguments = ["-dr", "com.apple.quarantine", stagedApp.path]
                try? xattrProc.run()
                xattrProc.waitUntilExit()

                return .success(stagedApp)
            } catch {
                return .failure(error)
            }
        }.value

        isExtracting = false
        switch extractResult {
        case .success(let stagedApp):
            self.stagedAppURL = stagedApp
            self.isReadyToRestart = true
            self.installStatusMessage = "新版本已准备就绪，点击「重启并更新」立即生效"
        case .failure(let error):
            self.isReadyToRestart = false
            self.installStatusMessage = "自动准备更新失败，您可以点击「打开 DMG」手动更新"
            self.activeAlert = .error("准备更新包失败: \(error.localizedDescription)")
        }
    }

    /// 重启当前应用并自动完成新版本覆盖
    public func relaunchAndInstall() {
        guard let stagedApp = stagedAppURL else {
            openDownloadedDMG()
            return
        }

        var targetAppPath = Bundle.main.bundlePath
        // 若在 DMG 卷内或非 .app 运行，回退至 /Applications/有用工具.app
        if targetAppPath.hasPrefix("/Volumes/") || !targetAppPath.hasSuffix(".app") {
            targetAppPath = "/Applications/有用工具.app"
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let scriptPath = NSTemporaryDirectory() + "pptools_updater_\(currentPID).sh"

        let scriptContent = """
        #!/bin/bash
        # 1. 等待原进程退出
        COUNT=0
        while kill -0 \(currentPID) 2>/dev/null; do
            sleep 0.1
            COUNT=$((COUNT + 1))
            if [ $COUNT -ge 30 ]; then
                kill -9 \(currentPID) 2>/dev/null || true
                break
            fi
        done

        # 2. 替换应用程序
        rm -rf "\(targetAppPath)"
        /usr/bin/ditto "\(stagedApp.path)" "\(targetAppPath)"
        rm -rf "\(stagedApp.path)"

        # 3. 移除隔离标识
        /usr/bin/xattr -dr com.apple.quarantine "\(targetAppPath)" 2>/dev/null || true

        # 4. 重新拉起新版应用
        /usr/bin/open "\(targetAppPath)"

        # 5. 清理脚本自身
        rm -f "\(scriptPath)"
        """

        do {
            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = [scriptPath]
            try proc.run()

            // 正常退出应用
            NSApp.terminate(nil)
            // 兜底：若 1 秒后仍未退出强制退出，让后台脚本接管
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                exit(0)
            }
        } catch {
            activeAlert = .error("启动更新脚本失败: \(error.localizedDescription)，请尝试手动安装。")
            openDownloadedDMG()
        }
    }

    // MARK: - URLSessionDownloadDelegate
    nonisolated public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0.0
        let writtenMB = Double(totalBytesWritten) / 1024.0 / 1024.0
        let totalMB = Double(totalBytesExpectedToWrite) / 1024.0 / 1024.0

        Task { @MainActor in
            self.downloadProgress = progress
            if totalBytesExpectedToWrite > 0 {
                self.installStatusMessage = String(format: "正在下载：%.1f MB / %.1f MB (%.0f%%)", writtenMB, totalMB, progress * 100)
            } else {
                self.installStatusMessage = String(format: "已下载：%.1f MB", writtenMB)
            }
        }
    }

    nonisolated public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let targetDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let fileName = downloadTask.response?.suggestedFilename ?? "有用工具-update.dmg"
        let destination = targetDir.appendingPathComponent(fileName)

        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            Task { @MainActor in
                self.isDownloading = false
                self.downloadProgress = 1.0
                self.downloadedDMGURL = destination
                // 启动后台自动提取解包
                await self.prepareDownloadedUpdate(dmgURL: destination)
            }
        } catch {
            Task { @MainActor in
                self.isDownloading = false
                self.activeAlert = .error("保存安装包失败: \(error.localizedDescription)")
            }
        }
    }

    nonisolated public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                if (error as NSError).code != NSURLErrorCancelled {
                    self.isDownloading = false
                    self.activeAlert = .error("下载失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
