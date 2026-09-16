import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct FontReplaceSheetView: View {
    public let sourceFonts: [String]
    public let sourceURL: URL
    public let onCompleted: (URL) -> Void

    @Environment(\.dismiss) private var dismiss

    // 推荐的常用系统字体
    private let recommendedFonts: [(id: String, name: String, category: String)] = [
        ("PingFang SC", "苹方-简", "推荐黑体"),
        ("Microsoft YaHei", "微软雅黑", "跨平台"),
        ("Heiti SC", "黑体-简", "经典黑体"),
        ("Songti SC", "宋体-简", "经典衬线"),
        ("Kaiti SC", "楷体-简", "传统书法"),
        ("Hiragino Sans GB", "冬青黑体", "清晰易读"),
        ("Arial", "Arial", "西文标准"),
        ("Helvetica Neue", "Helvetica Neue", "西文无衬线"),
        ("Times New Roman", "Times New Roman", "西文衬线")
    ]

    @State private var selectedTargetFont: String = "PingFang SC"
    @State private var searchText: String = ""
    @State private var isReplacing: Bool = false
    @State private var replaceProgress: Double = 0.0
    @State private var replaceStatusText: String = ""
    @State private var errorMessage: String? = nil
    @State private var allSystemFamilies: [String] = []

    public init(sourceFonts: [String], sourceURL: URL, onCompleted: @escaping (URL) -> Void) {
        self.sourceFonts = sourceFonts
        self.sourceURL = sourceURL
        self.onCompleted = onCompleted
    }

    private var filteredFamilies: [String] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return allSystemFamilies
        }
        return allSystemFamilies.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 头部标题与说明
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppleDesign.Colors.neutralAccent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppleDesign.Colors.neutralAccent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("替换字体")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppleDesign.Colors.primaryText)

                    Text(sourceFonts.count == 1 ? "将选中的 1 种字体全局替换为目标系统字体" : "将选中的 \(sourceFonts.count) 种字体批量替换为目标系统字体")
                        .font(.system(size: 12))
                        .foregroundStyle(AppleDesign.Colors.secondaryText)
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. 待替换的字体
                    VStack(alignment: .leading, spacing: 8) {
                        Text("待替换字体 (\(sourceFonts.count))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppleDesign.Colors.secondaryText)

                        FlowLayout(spacing: 6) {
                            ForEach(sourceFonts, id: \.self) { font in
                                HStack(spacing: 4) {
                                    Image(systemName: "textformat")
                                        .font(.system(size: 10))
                                    Text(font)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                    }

                    // 2. 常用系统自带字体推荐
                    VStack(alignment: .leading, spacing: 8) {
                        Text("推荐系统字体")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppleDesign.Colors.secondaryText)

                        FlowLayout(spacing: 8) {
                            ForEach(recommendedFonts, id: \.id) { item in
                                Button {
                                    selectedTargetFont = item.id
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(item.name)
                                            .font(.system(size: 12, weight: selectedTargetFont == item.id ? .semibold : .regular))

                                        Text(item.category)
                                            .font(.system(size: 10))
                                            .foregroundStyle(selectedTargetFont == item.id ? Color.white.opacity(0.85) : AppleDesign.Colors.tertiaryText)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedTargetFont == item.id ? AppleDesign.Colors.neutralAccent : Color.primary.opacity(0.04))
                                    .foregroundStyle(selectedTargetFont == item.id ? Color.white : AppleDesign.Colors.primaryText)
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 3. 所有系统字体搜索与选择
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("或选择系统中安装的任意字体")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppleDesign.Colors.secondaryText)

                            Spacer()

                            // 搜索过滤框
                            HStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppleDesign.Colors.tertiaryText)
                                TextField("搜索系统字体…", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11))
                                    .frame(width: 120)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }

                        Picker("目标字体", selection: $selectedTargetFont) {
                            ForEach(filteredFamilies, id: \.self) { family in
                                Text(family).tag(family)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    // 4. 实时效果预览
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("字样效果预览：\(selectedTargetFont)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppleDesign.Colors.secondaryText)
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("永和九年，岁在癸丑，暮春之初，会于会稽山阴之兰亭。")
                                .font(getPreviewFont(size: 13))
                                .foregroundStyle(AppleDesign.Colors.primaryText)
                            Text("The quick brown fox jumps over the lazy dog. 0123456789")
                                .font(getPreviewFont(size: 12))
                                .foregroundStyle(AppleDesign.Colors.secondaryText)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }

                    if let err = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.red)
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.red)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }

            Divider()

            // 底部操作栏
            HStack(spacing: 12) {
                if isReplacing {
                    ProgressView(value: replaceProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(width: 150)

                    Text(replaceStatusText.isEmpty ? "正在替换…" : replaceStatusText)
                        .font(.system(size: 11))
                        .foregroundStyle(AppleDesign.Colors.secondaryText)
                }

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isReplacing)

                Button {
                    startReplacement()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                        Text("替换并另存为…")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(AppleDesign.Colors.neutralAccent)
                .disabled(isReplacing || sourceFonts.isEmpty)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
        .frame(width: 540, height: 480)
        .onAppear {
            loadAvailableSystemFonts()
        }
    }

    private func getPreviewFont(size: CGFloat) -> Font {
        if NSFont(name: selectedTargetFont, size: size) != nil {
            return Font.custom(selectedTargetFont, size: size)
        }
        return Font.system(size: size)
    }

    private func loadAvailableSystemFonts() {
        let families = NSFontManager.shared.availableFontFamilies.sorted { a, b in
            a.localizedStandardCompare(b) == .orderedAscending
        }
        self.allSystemFamilies = families
    }

    private func startReplacement() {
        let savePanel = NSSavePanel()
        savePanel.title = "另存为替换字体后的演示文稿"
        savePanel.prompt = "保存"
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        savePanel.nameFieldStringValue = "\(baseName)-已替换字体.pptx"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "pptx") ?? .data]
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let destination = savePanel.url else {
            return
        }

        isReplacing = true
        replaceProgress = 0.05
        replaceStatusText = "正在准备替换…"
        errorMessage = nil

        let mapping = Dictionary(uniqueKeysWithValues: sourceFonts.map { ($0, selectedTargetFont) })

        Task {
            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try PPTXFontReplacer.replaceFonts(
                        in: sourceURL,
                        destinationURL: destination,
                        mapping: mapping
                    ) { p, msg in
                        Task { @MainActor in
                            self.replaceProgress = p
                            self.replaceStatusText = msg
                        }
                    }
                }.value

                await MainActor.run {
                    self.isReplacing = false
                    self.onCompleted(destination)
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isReplacing = false
                    self.errorMessage = "替换失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

/// 流式自适应换行布局（无外部依赖）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 500
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
        height = currentY + rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
    }
}
