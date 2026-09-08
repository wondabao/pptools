import SwiftUI
import AppKit

// MARK: - Parameters Sidebar Content

struct ConvertExportSidebarContent: View {
    @EnvironmentObject var model: AppModel
    private var isHero: Bool { model.templateID == "picpark-hero" }
    private var isRedBook: Bool { model.templateID == "picpark-redbook" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sourceFileSection
            Divider().opacity(0.4)
            templateSection
            if let template = model.config.custom, template.id != "picpark-redbook" && (template.backgroundHex != nil || template.backgroundImageName == nil) {
                Divider().opacity(0.4)
                appearanceColorSection(for: template)
            }
            if isRedBook {
                Divider().opacity(0.4)
                headerTextSection
            }
            Divider().opacity(0.4)
            detailSection
            Divider().opacity(0.4)
            outputSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(AppleDesign.Colors.neutralAccent)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    // MARK: - 0. Source File Section

    private var sourceFileSection: some View {
        SettingsGroup("源文件") {
            if let file = model.pdf {
                HStack(spacing: 12) {
                    PDFIconView(size: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.lastPathComponent)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(file.path)
                        Text(file.pathExtension.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                    Spacer()

                    Button {
                        model.choosePDF()
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
                    .help("更换 PDF…")
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    model.choosePDF()
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
                            Text("支持 PDF 演示文稿")
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
                .help("导入 PDF…")
            }
        }
    }

    // MARK: - 1. Template Selection (Visual Mockup Cards like 外观 浅色/深色/自动)

    private var templateSection: some View {
        SettingsGroup("版式模板") {
            HStack(spacing: 14) {
                TemplateVisualCard(
                    title: "详情长图",
                    subtitle: "PicPark · 35页",
                    templateID: "picpark-detail-35",
                    isSelected: model.templateID == "picpark-detail-35"
                ) {
                    model.templateID = "picpark-detail-35"
                    model.selectTemplate()
                }

                TemplateVisualCard(
                    title: "电商主图",
                    subtitle: "PicPark · 套装",
                    templateID: "picpark-hero",
                    isSelected: model.templateID == "picpark-hero"
                ) {
                    model.templateID = "picpark-hero"
                    model.selectTemplate()
                }

                TemplateVisualCard(
                    title: "小红书卡片",
                    subtitle: "PicPark · 5张",
                    templateID: "picpark-redbook",
                    isSelected: model.templateID == "picpark-redbook"
                ) {
                    model.templateID = "picpark-redbook"
                    model.selectTemplate()
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
    }

    // MARK: - 3. Appearance Background Color (macOS System Settings Color Row)

    private func appearanceColorSection(for template: TemplateManifest) -> some View {
        SettingsGroup("外观") {
            SettingsColorPickerRow(
                title: "背景颜色",
                selectedHex: $model.config.backgroundColorHex
            ) {
                model.updatePreview()
            }
        }
    }

    // MARK: - 4. Cover Text Fields (for RedBook)

    private var isDefaultTitle: Bool {
        model.config.redBookTitle == nil || model.config.redBookTitle == "红苹果设计师求职作品集"
    }

    private var isDefaultSubtitle: Bool {
        model.config.redBookSubtitle == nil || model.config.redBookSubtitle == "求职简历丨PSD+AI格式丨支持修改"
    }

    private var headerTextSection: some View {
        SettingsGroup("封面文字") {
            VStack(spacing: 0) {
                SettingsRow("主标题") {
                    HStack(spacing: 6) {
                        TextField("红苹果设计师求职作品集", text: Binding(
                            get: { model.config.redBookTitle ?? "红苹果设计师求职作品集" },
                            set: {
                                model.config.redBookTitle = $0
                                model.updatePreview()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(maxWidth: 160)

                        if !isDefaultTitle {
                            Button {
                                model.config.redBookTitle = nil
                                model.updatePreview()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.primary.opacity(0.6))
                            .help("恢复默认主标题")
                        }
                    }
                }

                SettingsDivider()

                SettingsRow("次文本") {
                    HStack(spacing: 6) {
                        TextField("求职简历丨PSD+AI格式丨支持修改", text: Binding(
                            get: { model.config.redBookSubtitle ?? "求职简历丨PSD+AI格式丨支持修改" },
                            set: {
                                model.config.redBookSubtitle = $0
                                model.updatePreview()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(maxWidth: 160)

                        if !isDefaultSubtitle {
                            Button {
                                model.config.redBookSubtitle = nil
                                model.updatePreview()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.primary.opacity(0.6))
                            .help("恢复默认次文本")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5. Detail Dimensions (输出尺寸)

    private struct WidthOption: Hashable {
        let width: Int
        let label: String
    }

    private func availableWidthOptions(for template: TemplateManifest) -> [WidthOption] {
        if template.id == "picpark-hero" {
            return [
                WidthOption(width: 800, label: "800px"),
                WidthOption(width: 1000, label: "1000px (1.2x)"),
                WidthOption(width: 1200, label: "1200px (1.5x)")
            ]
        } else if template.id == "picpark-redbook" {
            return [
                WidthOption(width: 1080, label: "1080px (1x)"),
                WidthOption(width: 1296, label: "1.2x"),
                WidthOption(width: 1620, label: "1.5x"),
                WidthOption(width: 2160, label: "2x")
            ]
        } else {
            // 详情长图及通用模版：默认1000px，支持 1x ~ 2x (步进 0.2x)
            return [
                WidthOption(width: 1000, label: "1x (1000px)"),
                WidthOption(width: 1200, label: "1.2x (1200px)"),
                WidthOption(width: 1400, label: "1.4x (1400px)"),
                WidthOption(width: 1600, label: "1.6x (1600px)"),
                WidthOption(width: 1800, label: "1.8x (1800px)"),
                WidthOption(width: 2000, label: "2x (2000px)")
            ]
        }
    }

    private var detailSection: some View {
        SettingsGroup("输出尺寸") {
            if let template = model.config.custom {
                let options = availableWidthOptions(for: template)
                let defaultWidth = options.first?.width ?? 1000
                let currentWidth = Int(model.config.templateOutputWidth ?? Double(defaultWidth))

                SettingsMenuPickerRow(
                    title: "输出宽度",
                    selection: Binding(
                        get: {
                            options.contains(where: { $0.width == currentWidth }) ? currentWidth : defaultWidth
                        },
                        set: { val in
                            model.config.templateOutputWidth = Double(val)
                        }
                    ),
                    options: options.map { ($0.width, $0.label) }
                )
            }
        }
    }

    // MARK: - 6. Output Options (导出设置 with Switch Toggles)

    private var outputSection: some View {
        SettingsGroup("导出设置") {
            VStack(spacing: 0) {
                SettingsRow("图片格式") {
                    Picker("图片格式", selection: $model.format) {
                        ForEach(ImageFormat.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .accessibilityLabel("导出图片格式")
                }

                SettingsDivider()

                SettingsRow("独立分页图片", subtitle: "将每页幻灯片导出为单独高清图片") {
                    Toggle("", isOn: $model.exportPages)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                SettingsDivider()

                let longTitle: String = {
                    if isHero { return "电商主图套装" }
                    if isRedBook { return "小红书卡片套装" }
                    return "整张详情长图"
                }()
                let longSubtitle: String = {
                    if isHero { return "导出全部 6 张主图卡片" }
                    if isRedBook { return "导出全部 5 张小红书展示卡片" }
                    return "无缝拼接为一张连续高分辨率长图"
                }()

                SettingsRow(longTitle, subtitle: longSubtitle) {
                    Toggle("", isOn: $model.exportLong)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                if model.config.custom?.trimsToContent == true {
                    SettingsDivider()
                    SettingsRow("保留完整模板高度", subtitle: "不根据实际页数自动裁剪底部留白") {
                        Toggle("", isOn: $model.config.keepFullTemplateHeight)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                }
            }
        }
    }
}

// MARK: - Parameters Sidebar Pinned Footer

struct ConvertExportFooterView: View {
    @EnvironmentObject var model: AppModel
    private var canExport: Bool {
        model.pdf != nil && !model.busy && (model.exportPages || model.exportLong)
    }

    private var estimatedSizeText: String {
        guard model.exportPages || model.exportLong else {
            return "请至少选择一项导出内容"
        }
        guard !model.images.isEmpty else {
            return "准备就绪"
        }

        // Calibrated empirical bytes per pixel based on actual exports
        let pageBpp: Double = (model.format == .jpeg) ? 0.13 : 0.45
        let stitchedBpp: Double = (model.format == .jpeg) ? 0.16 : 0.58
        var totalBytes: Double = 0

        // 1. Estimate standalone pages if enabled
        if model.exportPages {
            for img in model.images {
                let px = Double(img.width * img.height)
                totalBytes += px * pageBpp
            }
        }

        // 2. Estimate long stitched image or multi-cards if enabled
        if model.exportLong {
            if let custom = model.config.custom {
                let baseOutWidth = model.config.templateOutputWidth ?? Double(custom.subTemplates?.first?.width ?? custom.width)
                if let subs = custom.subTemplates, !subs.isEmpty {
                    var slideOffset = 0
                    for subTpl in subs {
                        guard slideOffset < model.images.count else { break }
                        let count = min(model.images.count - slideOffset, subTpl.slots.count)
                        guard count > 0 else { break }
                        slideOffset += count

                        let w = baseOutWidth
                        let h = Double(subTpl.height) * (baseOutWidth / Double(subTpl.width))
                        totalBytes += (w * h) * stitchedBpp
                    }
                } else {
                    var detailCount = model.images.count
                    if detailCount > 1 && detailCount % 2 == 0 {
                        detailCount -= 1
                    }
                    if detailCount > 0 {
                        let effectiveSizes = Array(repeating: CGSize(width: 1920, height: 1080), count: detailCount)
                        if let (refSize, _) = try? ImageEngine.layout(sizes: effectiveSizes, config: model.config) {
                            let w = baseOutWidth
                            let h = ceil(refSize.height * baseOutWidth / refSize.width)
                            totalBytes += (w * h) * stitchedBpp
                        }
                    }
                }
            } else {
                let w = model.config.width
                let h = Double(model.images.count) * (w * 9.0 / 16.0)
                totalBytes += (w * h) * stitchedBpp
            }
        }

        let mb = totalBytes / (1024 * 1024)
        if mb < 0.1 {
            let kb = max(1, Int(round(totalBytes / 1024)))
            return "导出图片预估：\(kb)KB"
        } else if mb < 10 {
            return String(format: "导出图片预估：%.1fMB", mb)
        } else {
            return "导出图片预估：\(Int(round(mb)))MB"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.busy {
                HStack {
                    Text(model.status).lineLimit(1)
                    Spacer()
                    Text("\(Int(model.progress * 100))%").monospacedDigit()
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                ProgressView(value: model.progress).controlSize(.small)
            } else if model.pdf != nil {
                Text(estimatedSizeText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Button(action: model.export) {
                Text(model.busy ? "正在处理…" : "生成并导出")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WorkbenchPrimaryButtonStyle())
            .keyboardShortcut("e", modifiers: .command)
            .disabled(!canExport)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
}

// MARK: - Preview Detail Stage

struct ConvertExportPreviewView: View {
    @EnvironmentObject var model: AppModel

    private var isMultiCard: Bool {
        model.config.custom?.subTemplates != nil && !(model.config.custom?.subTemplates?.isEmpty ?? true)
    }

    var body: some View {
        previewStage
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if let folder = model.resultFolder {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([folder])
                        } label: {
                            Label("输出目录", systemImage: "folder")
                        }
                        .help("在访达中查看最近导出的文件")
                    }

                    Button {
                        model.choosePDF()
                    } label: {
                        Label("导入 PDF", systemImage: "doc.badge.plus")
                    }
                    .keyboardShortcut("o", modifiers: .command)
                    .disabled(model.busy)
                    .help("导入用于制作详情图的 PDF (⌘O)")
                }
            }
            .onChange(of: model.config.templateOutputWidth) { model.updatePreview() }
            .onChange(of: model.config.keepFullTemplateHeight) { model.updatePreview() }
            .onChange(of: model.config.backgroundColorHex) { model.updatePreview() }
    }

    @ViewBuilder
    private var previewStage: some View {
        Group {
            if isMultiCard, !model.previewCards.isEmpty {
                multiCardPreviewStage
            } else if let preview = model.preview, !isMultiCard {
                singleImagePreviewStage(preview: preview)
            } else {
                emptyPreviewStage
            }
        }
        .background(AppleDesign.Colors.windowBackground)
    }

    // MARK: - Multi-Card Single View with Left/Right Navigation

    private var multiCardPreviewStage: some View {
        GeometryReader { geo in
            let currentIndex = min(max(0, model.previewCardIndex), model.previewCards.count - 1)
            let currentCard = model.previewCards[currentIndex]

            VStack(spacing: 12) {
                // Center Stage: One Card Displayed at a Time + Left/Right Switch Buttons
                HStack(spacing: 16) {
                    // Left Navigation Button
                    Button {
                        withAnimation(AppleDesign.Animation.spring) {
                            if model.previewCardIndex > 0 {
                                model.previewCardIndex -= 1
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(currentIndex > 0 ? Color.primary : Color.secondary.opacity(0.25))
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(AppleDesign.Colors.cardBorder, lineWidth: 0.5))
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentIndex == 0)
                    .help("上一张 (← / ⌘←)")

                    Spacer(minLength: 0)

                    // Card View + Centered Header Directly Above
                    VStack(spacing: 36) {
                        // Title and Card Index Counter (Centered directly above image)
                        HStack(spacing: 8) {
                            Text(currentCard.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppleDesign.Colors.primaryText)

                            Text("第 \(currentIndex + 1) / \(model.previewCards.count) 张")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                        }

                        // Card View: Centered, Fit Aspect Ratio, High-Definition Preview
                        Image(nsImage: currentCard.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                            }
                            .shadow(color: Color.black.opacity(0.10), radius: 20, x: 0, y: 6)
                            .id(currentCard.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                removal: .opacity
                            ))
                            .gesture(
                                DragGesture(minimumDistance: 25)
                                    .onEnded { value in
                                        if value.translation.width < -30 {
                                            if model.previewCardIndex < model.previewCards.count - 1 {
                                                withAnimation(AppleDesign.Animation.spring) {
                                                    model.previewCardIndex += 1
                                                }
                                            }
                                        } else if value.translation.width > 30 {
                                            if model.previewCardIndex > 0 {
                                                withAnimation(AppleDesign.Animation.spring) {
                                                    model.previewCardIndex -= 1
                                                }
                                            }
                                        }
                                    }
                            )
                    }

                    Spacer(minLength: 0)

                    // Right Navigation Button
                    Button {
                        withAnimation(AppleDesign.Animation.spring) {
                            if model.previewCardIndex < model.previewCards.count - 1 {
                                model.previewCardIndex += 1
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(currentIndex < model.previewCards.count - 1 ? Color.primary : Color.secondary.opacity(0.25))
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(AppleDesign.Colors.cardBorder, lineWidth: 0.5))
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentIndex >= model.previewCards.count - 1)
                    .help("下一张 (→ / ⌘→)")
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Pagination: Pill Dots
                HStack(spacing: 8) {
                    ForEach(model.previewCards.indices, id: \.self) { idx in
                        let isSelected = (idx == currentIndex)
                        Capsule()
                            .fill(isSelected ? AppleDesign.Colors.neutralAccent : Color.primary.opacity(0.2))
                            .frame(width: isSelected ? 22 : 6, height: 6)
                            .animation(AppleDesign.Animation.spring, value: isSelected)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(AppleDesign.Animation.spring) {
                                    model.previewCardIndex = idx
                                }
                            }
                    }
                }
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                // Invisible buttons providing keyboard shortcuts
                Group {
                    Button("") {
                        if model.previewCardIndex > 0 {
                            withAnimation(AppleDesign.Animation.spring) { model.previewCardIndex -= 1 }
                        }
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .opacity(0)

                    Button("") {
                        if model.previewCardIndex < model.previewCards.count - 1 {
                            withAnimation(AppleDesign.Animation.spring) { model.previewCardIndex += 1 }
                        }
                    }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .opacity(0)

                    Button("") {
                        if model.previewCardIndex > 0 {
                            withAnimation(AppleDesign.Animation.spring) { model.previewCardIndex -= 1 }
                        }
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                    .opacity(0)

                    Button("") {
                        if model.previewCardIndex < model.previewCards.count - 1 {
                            withAnimation(AppleDesign.Animation.spring) { model.previewCardIndex += 1 }
                        }
                    }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
                    .opacity(0)
                }
            }
        }
    }

    // MARK: - Single Image Long Stitch Stage (for Detail Long Images)

    private func singleImagePreviewStage(preview: NSImage) -> some View {
        GeometryReader { geo in
            let hPadding: CGFloat = 52
            let contentWidth = max(260, geo.size.width - hPadding * 2)
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    Image(nsImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: contentWidth)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
                        .padding(.vertical, 24)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, hPadding)
            }
            .themedScrollBars()
        }
    }

    // MARK: - Empty / Preparing Stage

    private var emptyPreviewStage: some View {
        Group {
            if model.pdf == nil {
                ContentUnavailableView {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(AppleDesign.Colors.neutralAccent)
                } actions: {
                    Button("选择 PDF 文件") {
                        model.choosePDF()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppleDesign.Colors.neutralAccent)
                    .controlSize(.regular)
                    .disabled(model.busy)
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("正在准备预览…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Compatibility Container

struct ConvertExportView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                ScrollView {
                    ConvertExportSidebarContent()
                }
                .themedScrollBars()
                ConvertExportFooterView()
            }
            .frame(minWidth: 300, idealWidth: 320, maxWidth: 360)
            .background(AppleDesign.Colors.sidebarBackground)

            ConvertExportPreviewView()
        }
    }
}

// MARK: - Reusable Primary Button Style

struct WorkbenchPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16).frame(height: 40)
            .foregroundStyle(enabled ? (scheme == .dark ? Color.black : Color.white) : Color.secondary)
            .background(enabled ? AppleDesign.Colors.neutralAccent : Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

// MARK: - Custom Color Manager

final class CustomColorManager: NSObject {
    static let shared = CustomColorManager()

    private var onColorChanged: ((String) -> Void)?

    func toggleColorPanel(currentHex: String, onColorChanged: @escaping (String) -> Void) {
        let panel = NSColorPanel.shared
        if panel.isVisible {
            panel.orderOut(nil)
            return
        }

        self.onColorChanged = onColorChanged
        if let color = NSColor(hex: currentHex) {
            panel.color = color
        }
        panel.isContinuous = true
        panel.showsAlpha = false
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelAction(_:)))
        panel.makeKeyAndOrderFront(nil)
        NSApp.orderFrontColorPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func colorPanelAction(_ sender: NSColorPanel) {
        let hex = sender.color.hexString
        onColorChanged?(hex)
    }

    func closePanel() {
        if NSColorPanel.sharedColorPanelExists {
            let panel = NSColorPanel.shared
            if panel.isVisible {
                panel.orderOut(nil)
            }
        }
    }
}
