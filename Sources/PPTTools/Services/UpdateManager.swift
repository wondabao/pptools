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

    @Published public var currentVersion: String = "0.1.0"
    @Published public var isChecking: Bool = false
    @Published public var hasNewVersion: Bool = false
    @Published public var latestRelease: GitHubRelease? = nil
    @Published public var showUpdateSheet: Bool = false
    @Published public var activeAlert: UpdateAlertType? = nil

    // 下载状态
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadSpeedText: String = ""
    @Published public var downloadedDMGURL: URL? = nil
    @Published public var installStatusMessage: String = ""

    private var downloadTask: URLSessionDownloadTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    public override init() {
        super.init()
        if let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !ver.isEmpty {
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
            tagName: "v0.1.1",
            name: "v0.1.1 - 官方网址与自动更新增强",
            body: "- 「关于」面板新增官方网站直达链接：https://www.yypic.com/\n- 支持 macOS 原生 DMG 安装包一键打包\n- 强化在线自动检测更新与下载安装体验",
            htmlUrl: "https://github.com/wondabao/pptools/releases/tag/v0.1.1",
            publishedAt: "2026-09-08T10:45:00Z",
            assets: [
                GitHubReleaseAsset(
                    name: "有用工具-v0.1.1.dmg",
                    browserDownloadUrl: "https://github.com/wondabao/pptools/releases/download/v0.1.1/有用工具-v0.1.1.dmg",
                    size: 5767168
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
        downloadProgress = 0.0
        installStatusMessage = ""
    }

    /// 打开下载到的 DMG 进行安装
    public func openDownloadedDMG() {
        guard let dmgURL = downloadedDMGURL else { return }
        NSWorkspace.shared.open(dmgURL)
        installStatusMessage = "已打开安装镜像，请拖拽更新应用"
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
                self.installStatusMessage = "下载完成，点击下方按钮立即打开安装"
                // 自动打开 DMG
                self.openDownloadedDMG()
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
