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
                .alert("已是最新版本", isPresented: $updateManager.showUpToDateAlert) {
                    Button("好", role: .cancel) {}
                } message: {
                    Text("当前已安装最新版本 (v\(updateManager.currentVersion))，无需更新。")
                }
                .alert("检查更新失败", isPresented: Binding(
                    get: { updateManager.updateError != nil },
                    set: { if !$0 { updateManager.updateError = nil } }
                )) {
                    Button("好", role: .cancel) {}
                } message: {
                    Text(updateManager.updateError ?? "网络连接异常，请稍后重试。")
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
}
