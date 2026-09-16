import SwiftUI
import AppKit

public struct UpdateSheetView: View {
    @ObservedObject var updateManager: UpdateManager
    @Environment(\.dismiss) private var dismiss

    public init(updateManager: UpdateManager) {
        self.updateManager = updateManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 头部：图标与版本信息
            HStack(spacing: 16) {
                if let logo = loadCleanAppLogo() {
                    Image(nsImage: logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                } else if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") ?? Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
                          let image = NSImage(contentsOf: iconURL) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppleDesign.Colors.neutralAccent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("发现新版本")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppleDesign.Colors.primaryText)

                    if let release = updateManager.latestRelease {
                        HStack(spacing: 6) {
                            Text("最新版本：\(release.tagName)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppleDesign.Colors.neutralAccent)

                            Text("•")
                                .font(.system(size: 11))
                                .foregroundStyle(AppleDesign.Colors.tertiaryText)

                            Text("当前版本：v\(updateManager.currentVersion)")
                                .font(.system(size: 12))
                                .foregroundStyle(AppleDesign.Colors.secondaryText)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // 中间：更新说明
            VStack(alignment: .leading, spacing: 8) {
                Text("更新内容与改进")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppleDesign.Colors.secondaryText)

                ScrollView {
                    Text(updateManager.latestRelease?.body ?? "此版本包含重要功能改进与使用体验优化。")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(AppleDesign.Colors.primaryText)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .background(AppleDesign.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppleDesign.Colors.hairline, lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(maxHeight: .infinity)

            Divider()

            // 底部：进度或操作按钮
            VStack(spacing: 12) {
                if updateManager.isDownloading {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: updateManager.downloadProgress, total: 1.0)
                            .progressViewStyle(.linear)

                        HStack {
                            Text(updateManager.installStatusMessage.isEmpty ? "正在下载更新包…" : updateManager.installStatusMessage)
                                .font(.system(size: 12))
                                .foregroundStyle(AppleDesign.Colors.secondaryText)

                            Spacer()

                            Button("取消") {
                                updateManager.cancelDownload()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppleDesign.Colors.secondaryText)
                            .font(.system(size: 12))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                } else if updateManager.isExtracting {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)

                        Text(updateManager.installStatusMessage.isEmpty ? "正在解压并准备新版本…" : updateManager.installStatusMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppleDesign.Colors.secondaryText)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                } else if updateManager.isReadyToRestart {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                            .font(.system(size: 18))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("新版本已准备就绪")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppleDesign.Colors.primaryText)

                            Text("重启后即可自动完成更新")
                                .font(.system(size: 11))
                                .foregroundStyle(AppleDesign.Colors.secondaryText)
                        }

                        Spacer()

                        if updateManager.downloadedDMGURL != nil {
                            Button("手动安装…") {
                                updateManager.openDownloadedDMG()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(AppleDesign.Colors.tertiaryText)
                        }

                        Button("稍后") {
                            updateManager.showUpdateSheet = false
                            dismiss()
                        }
                        .buttonStyle(.bordered)

                        Button("重启并更新") {
                            updateManager.relaunchAndInstall()
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .tint(AppleDesign.Colors.neutralAccent)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                } else if updateManager.downloadedDMGURL != nil {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                            .font(.system(size: 16))

                        Text("安装包已下载完成")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppleDesign.Colors.primaryText)

                        Spacer()

                        Button("重新打开 DMG") {
                            updateManager.openDownloadedDMG()
                        }
                        .buttonStyle(.bordered)

                        Button("完成") {
                            updateManager.showUpdateSheet = false
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppleDesign.Colors.neutralAccent)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                } else {
                    HStack(spacing: 12) {
                        if let urlStr = updateManager.latestRelease?.htmlUrl, let url = URL(string: urlStr) {
                            Button("在浏览器中查看") {
                                NSWorkspace.shared.open(url)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(AppleDesign.Colors.neutralAccent)
                        }

                        Spacer()

                        Button("稍后提醒") {
                            updateManager.showUpdateSheet = false
                            dismiss()
                        }
                        .keyboardShortcut(.cancelAction)

                        Button("立即下载更新") {
                            updateManager.startDownload()
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .tint(AppleDesign.Colors.neutralAccent)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                }
            }
        }
        .frame(width: 500, height: 380)
    }

    private func loadCleanAppLogo() -> NSImage? {
        let tryLoad: (URL?) -> NSImage? = { url in
            guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
            return NSImage(contentsOf: url)
        }

        // 1. Bundle.main 与 Contents/Resources (生产 .app 环境)
        if let img = tryLoad(Bundle.main.url(forResource: "logo", withExtension: "png")) {
            return img
        }
        if let resURL = Bundle.main.resourceURL {
            if let img = tryLoad(resURL.appendingPathComponent("logo.png")) { return img }
            if let img = tryLoad(resURL.appendingPathComponent("PPTTools_PPTTools.bundle/logo.png")) { return img }
        }

        // 2. 本地开发路径回退
        let devPaths = [
            "Sources/PPTTools/Resources/logo.png",
            "logo.png"
        ]
        for p in devPaths {
            if let img = tryLoad(URL(fileURLWithPath: p)) { return img }
        }

        // 3. Bundle.module 安全尝试
        #if SWIFT_PACKAGE
        if let moduleURL = Bundle.module.url(forResource: "logo", withExtension: "png") {
            if let img = tryLoad(moduleURL) { return img }
        }
        #endif

        return nil
    }
}
