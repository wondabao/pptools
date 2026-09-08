import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var source: URL?
    @Published var pdf: URL?
    @Published var report: FontReport?
    @Published var images: [CGImage] = []
    @Published var preview: NSImage?
    @Published var previewCards: [PreviewCardItem] = []
    @Published var previewCardIndex: Int = 0
    @Published var busy = false
    @Published var status = "导入一份演示文稿，开始整理你的灵感。"
    @Published var progress = 0.0
    @Published var error: String?
    @Published var config = StitchConfig()
    @Published var dpi = 72.0
    @Published var format: ImageFormat = .png
    @Published var templates: [TemplateManifest] = []
    @Published var templateID = ""
    @Published var exportPages = false
    @Published var exportLong = true
    @Published var resultFolder: URL?
    @Published var tab = 0
    @Published var templatePath = UserDefaults.standard.string(forKey: "templatePath") ?? NSHomeDirectory() + "/Desktop/PicPark"
    private var previewTask: Task<Void, Never>?
    private var revision = 0

    init() {
        config.backgroundColorHex = "#2457F0"
        reloadTemplates()
    }

    func chooseInput(pdfOnly: Bool = false) {
        let panel = NSOpenPanel()
        panel.title = pdfOnly ? "导入 PDF" : "导入演示文稿或 PDF"
        panel.prompt = "导入"
        panel.message = pdfOnly ? "请选择用于制作详情图的 PDF 文件。" : "请选择 PPTX 演示文稿或 PDF 文件。"
        panel.allowedContentTypes = pdfOnly ? [.pdf] : [.pdf, UTType(filenameExtension: "pptx") ?? .data]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { load(url, companion: pdfOnly && report != nil) }
    }

    func load(_ url: URL, companion: Bool = false) {
        guard !busy else { return }
        let ext = url.pathExtension.lowercased()
        guard ["pptx", "pdf"].contains(ext) else { error = "请选择 .pptx 或 .pdf 文件。"; return }
        busy = true; progress = 0.05; error = nil; resultFolder = nil
        if !companion { source = url }
        if ext == "pptx" {
            tab = 0
            status = "正在解压并读取演示文稿结构…"
        } else {
            status = "正在准备渲染 PDF 页面…"
        }
        Task {
            do {
                if ext == "pptx" {
                    let result = try await Task.detached(priority: .userInitiated) {
                        try PPTXParser.inspect(url) { p, msg in
                            Task { @MainActor in
                                self.progress = p
                                self.status = msg
                            }
                        }
                    }.value
                    revision += 1; previewTask?.cancel()
                    report = result; source = url; pdf = nil; images = []; preview = nil; previewCards = []; previewCardIndex = 0; tab = 0
                    status = "已检测 \(result.pageCount) 页，\(result.missing.count) 种字体缺失。"
                    progress = 1.0
                } else {
                    let rendered = try await Task.detached(priority: .userInitiated) {
                        try ImageEngine.renderPDF(url, dpi: 72) { p in
                            Task { @MainActor in
                                self.progress = p
                                self.status = "正在渲染 PDF 页面 (\(Int(p * 100))%)…"
                            }
                        }
                    }.value
                    if companion, let report, rendered.count != report.pageCount {
                        throw ToolError("PDF 共 \(rendered.count) 页，与 PPTX 的 \(report.pageCount) 页不同。请导入对应的 PDF。")
                    }
                    if !companion { source = url; report = nil }
                    pdf = url; images = rendered; tab = 1
                    previewCardIndex = 0
                    status = "已加载 \(rendered.count) 页 PDF，可以调整模板并导出。"
                    progress = 1.0
                    updatePreview()
                }
            } catch { self.error = error.localizedDescription; status = "导入失败，可重新选择文件。" }
            busy = false
        }
    }

    func updatePreview() {
        revision += 1
        let current = revision
        previewTask?.cancel()
        guard !images.isEmpty else {
            preview = nil
            previewCards = []
            return
        }
        let images = images, config = config
        previewTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(180))
                if let subs = config.custom?.subTemplates, !subs.isEmpty {
                    let isRedBook = (config.custom?.id == "picpark-redbook")
                    let names = isRedBook ?
                        ["封面展示", "内页浏览一", "内页浏览二", "内页浏览三", "尾页与引导"] :
                        ["封面合集", "亮点展示一", "亮点展示二", "亮点展示三", "亮点展示四", "服务保障"]

                    let worker = Task.detached(priority: .utility) { () -> [PreviewCardItem] in
                        var items: [PreviewCardItem] = []
                        var slideOffset = 0
                        for (idx, subTpl) in subs.enumerated() {
                            guard slideOffset < images.count else { break }
                            let count = min(images.count - slideOffset, subTpl.slots.count)
                            guard count > 0 else { break }
                            let subImages = Array(images[slideOffset..<(slideOffset + count)])
                            slideOffset += count
                            var subConfig = config
                            subConfig.custom = subTpl
                            let cg = try ImageEngine.stitch(subImages, config: subConfig, preview: true)
                            let roleName = idx < names.count ? names[idx] : "第\(idx + 1)张"
                            items.append(PreviewCardItem(id: idx, title: roleName, image: NSImage(cgImage: cg, size: .zero)))
                        }
                        return items
                    }
                    let renderedCards = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                    guard current == revision, !Task.isCancelled else { return }
                    previewCards = renderedCards
                    if previewCardIndex >= renderedCards.count {
                        previewCardIndex = max(0, renderedCards.count - 1)
                    }
                    preview = renderedCards.first?.image
                } else {
                    var detailImages = images
                    if detailImages.count > 1 && detailImages.count % 2 == 0 {
                        detailImages = Array(detailImages.dropLast())
                    }
                    let worker = Task.detached(priority: .utility) { try ImageEngine.stitch(detailImages, config: config, preview: true) }
                    let rendered = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                    guard current == revision, !Task.isCancelled else { return }
                    preview = NSImage(cgImage: rendered, size: .zero)
                    previewCards = []
                }
            } catch is CancellationError {} catch {
                guard current == revision else { return }
                preview = nil
                previewCards = []
                self.error = error.localizedDescription
            }
        }
    }

    func selectTemplate() {
        previewCardIndex = 0
        config.custom = templates.first { $0.id == templateID }
        if let defaultHex = config.custom?.backgroundHex, !defaultHex.isEmpty {
            config.backgroundColorHex = defaultHex
        } else if templateID == "picpark-detail-35" || templateID == "picpark-hero" {
            config.backgroundColorHex = "#2457F0"
        } else {
            config.backgroundColorHex = nil
        }
        if templateID == "picpark-hero" {
            if config.templateOutputWidth == nil || config.templateOutputWidth == 1872 || config.templateOutputWidth == 1440 {
                config.templateOutputWidth = 1000
            }
        } else if templateID == "picpark-redbook" {
            if config.templateOutputWidth == nil || config.templateOutputWidth == 1872 || config.templateOutputWidth == 1000 {
                config.templateOutputWidth = 1440
            }
        } else if templateID == "picpark-detail-35" {
            if config.templateOutputWidth == nil || config.templateOutputWidth == 1872 {
                config.templateOutputWidth = 1000
            }
        }
        updatePreview()
    }

    func chooseTemplateFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.title = "选择模板目录"; panel.prompt = "选择目录"
        if panel.runModal() == .OK, let url = panel.url {
            templatePath = url.path; UserDefaults.standard.set(url.path, forKey: "templatePath"); reloadTemplates()
        }
    }

    func reloadTemplates() {
        var loaded: [TemplateManifest] = []
        var failures: [String] = []
        if let url = Bundle.main.url(forResource: "templates", withExtension: "json") ?? Bundle.module.url(forResource: "templates", withExtension: "json"),
           let data = try? Data(contentsOf: url), let bundled = try? JSONDecoder().decode([TemplateManifest].self, from: data) {
            for item in bundled {
                do { try item.validate(); loaded.append(item) }
                catch { failures.append("内置模板 \(item.name)：\(error.localizedDescription)") }
            }
        }
        let folder = URL(fileURLWithPath: templatePath)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        for url in files.filter({ $0.pathExtension.lowercased() == "json" }) {
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 2_000_000 else { throw ToolError("配置超过 2MB") }
                let item = try JSONDecoder().decode(TemplateManifest.self, from: Data(contentsOf: url))
                try item.validate()
                guard !loaded.contains(where: { $0.id == item.id }) else { throw ToolError("模板 ID 重复") }
                loaded.append(item)
            } catch { failures.append("\(url.lastPathComponent)：\(error.localizedDescription)") }
        }
        templates = loaded
        if !templates.contains(where: { $0.id == templateID }) {
            templateID = templates.first(where: { $0.id == "picpark-detail-35" })?.id ?? templates.first?.id ?? ""
        }
        if !failures.isEmpty { error = failures.joined(separator: "\n") }
        selectTemplate()
    }

    func extract(_ font: FontItem) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.prompt = "提取到此处"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            let decoded = try font.embedded.map { embedded -> (Data, String) in
                let (data, ext) = try EmbeddedFontExtractor.decode(embedded.data)
                let safe = (font.name + "-" + embedded.style).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
                return (data, safe + "." + ext)
            }
            let folder = destination.appendingPathComponent("提取字体-" + UUID().uuidString.prefix(8))
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for (data, name) in decoded { try data.write(to: folder.appendingPathComponent(name), options: .atomic) }
            NSWorkspace.shared.activateFileViewerSelecting([folder]); status = "字体文件已提取。"
        } catch { self.error = error.localizedDescription }
    }

    func export() {
        guard let pdf, !busy, exportPages || exportLong else { return }
        let destination = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
        let config = config, dpi = dpi, format = format, pages = exportPages, long = exportLong
        let baseName = (source ?? pdf)?.deletingPathExtension().lastPathComponent ?? ""
        busy = true; progress = 0; status = "正在生成导出图片至桌面…"; error = nil; resultFolder = nil
        Task {
            do {
                let (exportedItems, pageFolderURL) = try await Task.detached(priority: .userInitiated) { [weak self] in
                    let fm = FileManager.default
                    let staging = fm.temporaryDirectory.appendingPathComponent("pptools-" + UUID().uuidString)
                    try fm.createDirectory(at: staging, withIntermediateDirectories: true)
                    var completed = false
                    defer { if !completed { try? fm.removeItem(at: staging) } }
                    var createdPageFolder: URL? = nil

                    if pages || long {
                        let rendered = try ImageEngine.renderPDF(pdf, dpi: dpi) { value in
                            Task { @MainActor [weak self] in self?.progress = value * 0.65 }
                        }
                        if pages {
                            let folderName = baseName.isEmpty ? "分页图片" : "\(baseName)-分页图片"
                            let pageFolder = staging.appendingPathComponent(folderName)
                            try fm.createDirectory(at: pageFolder, withIntermediateDirectories: true)
                            for (index, image) in rendered.enumerated() {
                                let pageName = String(format: "%03d.%@", index + 1, format.ext)
                                try ImageEngine.write(image, to: pageFolder.appendingPathComponent(pageName), format: format, dpi: dpi)
                            }
                        }
                        if long {
                            if let subs = config.custom?.subTemplates, !subs.isEmpty {
                                let isRedBook = (config.custom?.id == "picpark-redbook")
                                let names = isRedBook ?
                                    ["封面展示", "内页浏览一", "内页浏览二", "内页浏览三", "尾页与引导"] :
                                    ["封面合集", "亮点展示一", "亮点展示二", "亮点展示三", "亮点展示四", "服务保障"]
                                let prefix = isRedBook ? "小红书" : "电商主图"
                                var slideOffset = 0
                                for (idx, subTpl) in subs.enumerated() {
                                    guard slideOffset < rendered.count else { break }
                                    let count = min(rendered.count - slideOffset, subTpl.slots.count)
                                    guard count > 0 else { break }
                                    let subImages = Array(rendered[slideOffset..<(slideOffset + count)])
                                    slideOffset += count
                                    var subConfig = config
                                    subConfig.custom = subTpl
                                    let image = try ImageEngine.stitch(subImages, config: subConfig)
                                    let roleName = idx < names.count ? names[idx] : "第\(idx + 1)张"
                                    let filename = String(format: "%@_%02d_%@.%@", prefix, idx + 1, roleName, format.ext)
                                    try ImageEngine.write(image, to: staging.appendingPathComponent(filename), format: format)
                                }
                            } else {
                                var detailImages = rendered
                                if detailImages.count > 1 && detailImages.count % 2 == 0 {
                                    detailImages = Array(detailImages.dropLast())
                                }
                                let image = try ImageEngine.stitch(detailImages, config: config)
                                let filename: String = {
                                    if config.custom?.id == "picpark-hero" { return "电商主图." }
                                    if config.custom?.id == "picpark-redbook" { return "小红书卡片." }
                                    return "详情长图."
                                }()
                                try ImageEngine.write(image, to: staging.appendingPathComponent(filename + format.ext), format: format)
                            }
                        }
                    }
                    let stagedFiles = try fm.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil)
                    var finalItems: [URL] = []
                    for file in stagedFiles {
                        let target = destination.appendingPathComponent(file.lastPathComponent)
                        if fm.fileExists(atPath: target.path) {
                            try? fm.removeItem(at: target)
                        }
                        try fm.moveItem(at: file, to: target)
                        finalItems.append(target)
                        if file.lastPathComponent.hasSuffix("分页图片") {
                            createdPageFolder = target
                        }
                    }
                    completed = true
                    try? fm.removeItem(at: staging)
                    return (finalItems, createdPageFolder)
                }.value
                resultFolder = pageFolderURL ?? exportedItems.first ?? destination
                progress = 1
                if let pageFolderURL {
                    status = "导出完成，分页图片已保存至桌面文件夹 \(pageFolderURL.lastPathComponent)。"
                } else {
                    status = "导出完成，已保存至桌面（共 \(exportedItems.count) 张）。"
                }
                if !exportedItems.isEmpty {
                    NSWorkspace.shared.activateFileViewerSelecting(exportedItems)
                }
            } catch { self.error = error.localizedDescription; status = "导出失败，请调整参数后重试。" }
            busy = false
        }
    }
}
