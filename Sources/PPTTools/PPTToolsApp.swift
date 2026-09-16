import SwiftUI
import AppKit



final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindows()
    }

    func setupWindows() {
        for window in NSApp.windows {
            configure(window)
        }
    }

    func configure(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbar?.showsBaselineSeparator = false
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 1060, height: 720)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            configure(window)
        }
    }
}

@main
struct PPTToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var updateManager = UpdateManager.shared

    init() {
        TableHeaderThemeHelper.installHeaderHooks()
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") ?? Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(model)
                .onOpenURL { model.load($0) }
                .sheet(isPresented: $updateManager.showUpdateSheet) {
                    UpdateSheetView(updateManager: updateManager)
                }
                .alert(item: $updateManager.activeAlert) { alert in
                    switch alert {
                    case .upToDate(let version):
                        return Alert(
                            title: Text("已是最新版本"),
                            message: Text("当前已安装最新版本 (v\(version))，暂无可用更新。"),
                            dismissButton: .default(Text("好"))
                        )
                    case .error(let message):
                        return Alert(
                            title: Text("检查更新失败"),
                            message: Text(message),
                            dismissButton: .default(Text("好"))
                        )
                    }
                }
                .task {
                    // 启动后延迟 1.5 秒静默检测更新，避免占用冷启动资源
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    updateManager.checkForUpdates(manual: false)
                }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 820)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于有用工具") {
                    showAboutPanel()
                }
            }
            CommandGroup(after: .appInfo) {
                Button("检查更新…") {
                    updateManager.checkForUpdates(manual: true)
                }
                .disabled(updateManager.isChecking)
            }
            CommandGroup(replacing: .newItem) {
                Button("导入 PPTX 或 PDF…") { model.chooseInput() }.keyboardShortcut("o").disabled(model.busy)
            }
        }
    }

    private func showAboutPanel() {
        let url = URL(string: "https://www.yypic.com/")!
        let text = "官方网站：https://www.yypic.com/"
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        let range = (text as NSString).range(of: "https://www.yypic.com/")
        attrString.addAttribute(.link, value: url, range: range)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? updateManager.currentVersion
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .credits: attrString,
            .applicationName: "有用工具",
            .applicationVersion: version,
            .version: "" // 置空以去除 (Build) 括号，仅显示纯版本号例如 "版本 1.0.1"
        ]
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") ?? Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            options[.applicationIcon] = icon
        }
        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
    }
}
