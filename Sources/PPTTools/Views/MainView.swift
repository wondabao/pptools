import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Workspace Navigation Enum

enum WorkspaceTab: Int, Hashable, CaseIterable, Identifiable {
    case fontInspect = 0
    case convertExport = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fontInspect: return "字体检测"
        case .convertExport: return "图片生成"
        }
    }

    var iconName: String {
        switch self {
        case .fontInspect: return "text.magnifyingglass"
        case .convertExport: return "photo.stack"
        }
    }
}

// MARK: - Main Container View

struct MainView: View {
    @EnvironmentObject var model: AppModel
    @State private var isDropTargeted = false
    @State private var selectedTab: WorkspaceTab = .fontInspect
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            AppSidebarView(selectedTab: $selectedTab)
                .navigationSplitViewColumnWidth(min: 270, ideal: 300, max: 360)
                .background(AppleDesign.Colors.sidebarBackground)
        } detail: {
            Group {
                switch selectedTab {
                case .fontInspect:
                    FontInspectView()
                case .convertExport:
                    ConvertExportPreviewView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppleDesign.Colors.windowBackground)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    CalendarSegmentedPicker(
                        titles: WorkspaceTab.allCases.map(\.title),
                        selectedIndex: Binding(
                            get: { selectedTab.rawValue },
                            set: {
                                if let t = WorkspaceTab(rawValue: $0) {
                                    selectedTab = t
                                    model.tab = $0
                                }
                            }
                        )
                    )
                    .frame(width: 230, height: 36)
                }
            }
        }
        .tint(AppleDesign.Colors.neutralAccent)
        .frame(minWidth: 1060, minHeight: 720)
        .background(WindowAccessor { window in
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.toolbar?.showsBaselineSeparator = false
            window.titleVisibility = .hidden
            window.minSize = NSSize(width: 1060, height: 720)
            ThemedScrollerHelper.applyRecursively(to: window.contentView)
        })
        .onChange(of: model.tab) { _, newTab in
            if let tab = WorkspaceTab(rawValue: newTab), tab != selectedTab {
                selectedTab = tab
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab.rawValue != model.tab {
                model.tab = newTab.rawValue
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                ThemedScrollerHelper.applyRecursively(to: NSApp.keyWindow?.contentView)
            }
        }
        .onChange(of: model.report != nil) { _, hasReport in
            if hasReport {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    ThemedScrollerHelper.applyRecursively(to: NSApp.keyWindow?.contentView)
                }
            }
        }
        .onAppear {
            selectedTab = WorkspaceTab(rawValue: model.tab) ?? .fontInspect
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard !model.busy, let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    Task { @MainActor in
                        withAnimation(AppleDesign.Animation.spring) {
                            model.load(url)
                        }
                    }
                }
            }
            return true
        }
        .alert("操作未完成", isPresented: Binding(
            get: { model.error != nil },
            set: { if !$0 { model.error = nil } }
        )) {
            Button("好", role: .cancel) { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
    }
}

// MARK: - App Sidebar View

struct AppSidebarView: View {
    @EnvironmentObject var model: AppModel
    @Binding var selectedTab: WorkspaceTab

    var body: some View {
        Group {
            switch selectedTab {
            case .convertExport:
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        ConvertExportSidebarContent()
                    }
                    ConvertExportFooterView()
                }
            case .fontInspect:
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        FontInspectSidebarContent()
                    }
                    if model.report != nil {
                        FontInspectSidebarFooter()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppleDesign.Colors.sidebarBackground)
    }
}

// MARK: - Font Inspect Sidebar Content

struct FontInspectSidebarContent: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup("源文件") {
                if let source = model.source {
                    HStack(spacing: 12) {
                        if source.pathExtension.lowercased() == "pdf" {
                            PDFIconView(size: 32)
                        } else {
                            PPTIconView(size: 32)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.lastPathComponent)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(source.path)
                            Text(source.pathExtension.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                        }
                        Spacer()

                        Button {
                            model.chooseInput()
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.primary)
                                .frame(width: 28, height: 28)
                                .background(Color.primary.opacity(0.06), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(model.busy)
                        .opacity(model.busy ? 0.4 : 1.0)
                        .help("更换演示文稿…")
                    }
                    .padding(.vertical, 4)
                } else {
                    Button {
                        model.chooseInput()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 24))
                                .foregroundStyle(AppleDesign.Colors.secondaryText)
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("未导入文件")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.primary)
                                Text("支持 PPTX 与 PDF 演示文稿")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.busy)
                    .help("导入演示文稿…")
                }
            }

            Divider().opacity(0.4)

            SettingsGroup("检测概览") {
                VStack(spacing: 10) {
                    AppleMetricCard(
                        title: "幻灯片数量",
                        value: model.report?.pageCount ?? 0,
                        systemImage: "doc.on.doc",
                        accentColor: Color.primary
                    )

                    AppleMetricCard(
                        title: "字体声明",
                        value: model.report?.fonts.count ?? 0,
                        systemImage: "textformat",
                        accentColor: Color.primary
                    )

                    AppleMetricCard(
                        title: "缺失字体",
                        value: model.report?.missing.count ?? 0,
                        systemImage: "exclamationmark.triangle",
                        accentColor: Color.primary,
                        valueColor: (model.report?.missing.isEmpty == false) ? AppleDesign.Colors.warning : nil
                    )
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }
}

// MARK: - Font Inspect Sidebar Footer

struct FontInspectSidebarFooter: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            Button {
                if let url = model.source {
                    withAnimation(AppleDesign.Animation.spring) {
                        model.load(url)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("重新检测")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(WorkbenchPrimaryButtonStyle())
            .disabled(model.busy || model.source == nil)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
}

// MARK: - Font Inspection View (Tab 0)

struct FontInspectView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.busy && model.report == nil {
                fontInspectLoadingStage
            } else if let report = model.report {
                VStack(alignment: .leading, spacing: AppleDesign.Spacing.md) {
                if model.busy {
                    fontInspectReinspectingBanner
                }


                // Modern Font Inventory Table
                Table(report.fonts) {
                    TableColumn("字体名称") { font in
                        FontNameCell(fontName: font.name)
                    }
                    .width(min: 180, ideal: 200, max: 220)

                    TableColumn("安装状态") { font in
                        if font.installed {
                            AppleStatusPill(title: "已安装", systemImage: "checkmark.circle.fill", color: AppleDesign.Colors.success)
                        } else if !font.embedded.isEmpty {
                            AppleStatusPill(title: "已内嵌", systemImage: "archivebox.fill", color: Color.primary.opacity(0.7))
                        } else {
                            AppleStatusPill(title: "缺失", systemImage: "exclamationmark.circle.fill", color: AppleDesign.Colors.warning)
                        }
                    }
                    .width(min: 90, ideal: 100, max: 110)

                    TableColumn("引用页码") { font in
                        FontPagesCell(fontName: font.name, pages: font.pages)
                    }
                    .width(min: 100, ideal: 160)

                    TableColumn("操作") { font in
                        if !font.embedded.isEmpty {
                            Button {
                                model.extract(font)
                            } label: {
                                Label("提取", systemImage: "arrow.down.circle")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(model.busy)
                        }
                    }
                    .width(min: 90, ideal: 110, max: 130)
                }
                .appleCard(cornerRadius: AppleDesign.Radius.md, padding: 0)
                .themedScrollBars()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        ThemedScrollerHelper.applyRecursively(to: NSApp.keyWindow?.contentView)
                    }
                }

                // Warnings Callout (if any)
                if !report.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(report.warnings, id: \.self) { warning in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppleDesign.Colors.warning)
                                Text(warning)
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppleDesign.Colors.secondaryText)
                            }
                        }
                    }
                    .padding(AppleDesign.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(AppleDesign.Radius.sm)
                }

            }
            .padding(AppleDesign.Spacing.lg)
        } else {
            // Official ContentUnavailableView Empty State
            ContentUnavailableView {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(AppleDesign.Colors.neutralAccent)
            } actions: {
                Button("选择 PPTX 文件") {
                    model.chooseInput()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppleDesign.Colors.neutralAccent)
                .controlSize(.regular)
                .disabled(model.busy)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let report = model.report {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(
                            report.missing.map(\.name).joined(separator: "\n"),
                            forType: .string
                        )
                    } label: {
                        Label("复制缺失字体", systemImage: "doc.on.clipboard")
                    }
                    .disabled(report.missing.isEmpty)
                    .help("复制所有缺失字体的名称到剪贴板")

                    Button {
                        if let url = model.source {
                            withAnimation(AppleDesign.Animation.spring) {
                                model.load(url)
                            }
                        }
                    } label: {
                        Label("重新检测", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.busy)
                    .help("重新检测当前文件")
                }

                if let folder = model.resultFolder {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([folder])
                    } label: {
                        Label("输出目录", systemImage: "folder")
                    }
                    .help("在访达中查看最近导出的文件")
                }

                Button {
                    model.chooseInput()
                } label: {
                    Label("导入文件", systemImage: "doc.badge.plus")
                }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(model.busy)
                .help("导入演示文稿或 PDF (⌘O)")
            }
        }
    }

    // MARK: - Loading Stage with Progress Bar

    private var fontInspectLoadingStage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 88, height: 88)

                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(AppleDesign.Colors.neutralAccent)
            }

            VStack(spacing: 8) {
                if let source = model.source {
                    HStack(spacing: 8) {
                        if source.pathExtension.lowercased() == "pdf" {
                            PDFIconView(size: 18)
                        } else {
                            PPTIconView(size: 18)
                        }
                        Text(source.lastPathComponent)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppleDesign.Colors.primaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                } else {
                    Text("正在进行字体检测")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppleDesign.Colors.primaryText)
                }

                Text(model.status)
                    .font(.system(size: 13))
                    .foregroundStyle(AppleDesign.Colors.secondaryText)
            }

            VStack(spacing: 8) {
                ProgressView(value: max(0.02, model.progress), total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(AppleDesign.Colors.neutralAccent)
                    .frame(width: 320)

                HStack {
                    Text("检测进度")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(model.progress * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 320)
            }
            .padding(.top, 4)

            HStack(spacing: 12) {
                AppleStatusPill(title: "逐页母版扫描", systemImage: "doc.on.doc", color: Color.primary.opacity(0.75))
                AppleStatusPill(title: "内嵌字体提取支持", systemImage: "archivebox", color: Color.primary.opacity(0.75))
                AppleStatusPill(title: "系统字库比对", systemImage: "checkmark.shield", color: Color.primary.opacity(0.75))
            }
            .padding(.top, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Reinspecting Banner

    private var fontInspectReinspectingBanner: some View {
        HStack(spacing: 14) {
            ProgressView().controlSize(.small)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppleDesign.Colors.primaryText)
                    .lineLimit(1)

                ProgressView(value: max(0.02, model.progress), total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(AppleDesign.Colors.neutralAccent)
                    .frame(width: 240)
            }

            Spacer()

            Text("\(Int(model.progress * 100))%")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppleDesign.Colors.secondaryText)
        }
        .appleCard(cornerRadius: AppleDesign.Radius.md, padding: AppleDesign.Spacing.sm)
    }
}

// MARK: - Font Name Cell (Click to copy)

private struct FontNameCell: View {
    let fontName: String
    @State private var isCopied = false
    @State private var isHovered = false

    var body: some View {
        Button {
            copyFontName()
        } label: {
            HStack(spacing: 6) {
                Text(fontName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppleDesign.Colors.primaryText)
                    .lineLimit(1)

                if isCopied {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("已复制")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(AppleDesign.Colors.success)
                    .transition(.opacity.combined(with: .scale))
                } else if isHovered {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(AppleDesign.Colors.secondaryText)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help("点击复制字体名称")
        .contextMenu {
            Button {
                copyFontName()
            } label: {
                Label("复制字体名称", systemImage: "doc.on.doc")
            }
        }
    }

    private func copyFontName() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fontName, forType: .string)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}

// MARK: - Font Pages Cell (Hover Card)

private struct FontPagesCell: View {
    let fontName: String
    let pages: Set<Int>

    @State private var isShowingPopover = false
    @State private var closeWorkItem: DispatchWorkItem?
    @State private var isCopied = false

    var sortedPages: [Int] {
        pages.sorted()
    }

    var summaryText: String {
        if pages.isEmpty {
            return "仅母版声明"
        }
        return sortedPages.map(String.init).joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(summaryText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppleDesign.Colors.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            if pages.count > 3 {
                Text("\(pages.count)页")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppleDesign.Colors.secondaryText)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                closeWorkItem?.cancel()
                closeWorkItem = nil
                isShowingPopover = true
            } else {
                let work = DispatchWorkItem {
                    isShowingPopover = false
                }
                closeWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
            }
        }
        .popover(isPresented: $isShowingPopover, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(AppleDesign.Colors.neutralAccent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(fontName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppleDesign.Colors.primaryText)
                            .lineLimit(1)
                        Text(pages.isEmpty ? "母版声明字体" : "共在 \(pages.count) 张幻灯片中引用")
                            .font(.system(size: 10))
                            .foregroundStyle(AppleDesign.Colors.secondaryText)
                    }

                    Spacer(minLength: 12)

                    if !pages.isEmpty {
                        Button {
                            let text = sortedPages.map(String.init).joined(separator: ", ")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                            withAnimation {
                                isCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    isCopied = false
                                }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 9))
                                Text(isCopied ? "已复制" : "复制页码")
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(isCopied ? AppleDesign.Colors.success : AppleDesign.Colors.primaryText)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }

                Divider()

                // Content
                if pages.isEmpty {
                    Text("此字体仅在幻灯片母版或版式中声明，未在具体正文页面中被直接使用。")
                        .font(.system(size: 11))
                        .foregroundStyle(AppleDesign.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ScrollView(.vertical) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 38, maximum: 46), spacing: 6)], spacing: 6) {
                            ForEach(sortedPages, id: \.self) { page in
                                Text("\(page)")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(AppleDesign.Colors.primaryText)
                                    .frame(minWidth: 38, minHeight: 24)
                                    .background(Color.primary.opacity(0.06))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 180)
                }
            }
            .padding(14)
            .frame(width: 290)
            .onHover { insidePopover in
                if insidePopover {
                    closeWorkItem?.cancel()
                    closeWorkItem = nil
                } else {
                    let work = DispatchWorkItem {
                        isShowingPopover = false
                    }
                    closeWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
                }
            }
        }
    }
}

