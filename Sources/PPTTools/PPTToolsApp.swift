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
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("导入 PPTX 或 PDF…") { model.chooseInput() }.keyboardShortcut("o").disabled(model.busy)
            }
        }
    }
}
