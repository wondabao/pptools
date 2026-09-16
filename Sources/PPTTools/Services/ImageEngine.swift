import AppKit
import PDFKit
import ImageIO
import UniformTypeIdentifiers

struct ImageEngine {
    static let pixelLimit = 80_000_000.0
    static func context(width: Int, height: Int) throws -> CGContext {
        guard width > 0, height > 0, width <= 16000, height <= 60000,
              Double(width) * Double(height) <= pixelLimit,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ToolError("图像过大（上限 8000 万像素 / 60000px 高）。请降低宽度、DPI 或减少页数。") }
        return context
    }

    static func renderPDF(_ url: URL, dpi: Double, progress: @escaping (Double) -> Void = { _ in }) throws -> [CGImage] {
        guard let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else { throw ToolError("PDF 无法打开、已加密或没有页面。") }
        guard document.pageCount <= 500 else { throw ToolError("首版支持最多 500 页 PDF，请拆分后重试。") }
        var images: [CGImage] = []
        var totalPixels = 0.0
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            let image: CGImage = try autoreleasepool {
                guard let page = document.page(at: index), let pageRef = page.pageRef else { throw ToolError("无法读取第 \(index + 1) 页。") }
                let bounds = page.bounds(for: .cropBox)
                let rotated = abs(page.rotation % 180) == 90
                let pageWidth = rotated ? bounds.height : bounds.width
                let pageHeight = rotated ? bounds.width : bounds.height
                let w = ceil(pageWidth * dpi / 72), h = ceil(pageHeight * dpi / 72)
                guard w.isFinite, h.isFinite, w > 0, h > 0, w <= 16000, h <= 60000 else { throw ToolError("PDF 页面尺寸无效或过大。") }
                totalPixels += w * h
                guard totalPixels <= 120_000_000 else { throw ToolError("分页图像总量超过内存预算，请降低 DPI 或拆分 PDF。") }
                let context = try context(width: Int(w), height: Int(h))
                let rect = CGRect(x: 0, y: 0, width: w, height: h)
                context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(rect)
                // CGPDFPage's fitting transform does not reliably upscale smaller pages.
                // Apply DPI explicitly, then fit crop/rotation in page-point space.
                context.scaleBy(x: w / pageWidth, y: h / pageHeight)
                context.concatenate(pageRef.getDrawingTransform(.cropBox, rect: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), rotate: 0, preserveAspectRatio: true))
                context.drawPDFPage(pageRef)
                guard let image = context.makeImage() else { throw ToolError("PDF 页面渲染失败。") }
                return image
            }
            images.append(image)
            progress(Double(index + 1) / Double(document.pageCount))
        }
        return images
    }

    static func layout(sizes: [CGSize], config: StitchConfig) throws -> (CGSize, [CGRect]) {
        guard !sizes.isEmpty, sizes.allSatisfy({ $0.width.isFinite && $0.height.isFinite && $0.width > 0 && $0.height > 0 }) else { throw ToolError("请先导入页面。") }
        if let custom = config.custom {
            try custom.validate()
            let effectiveSizes = (custom.subTemplates != nil && sizes.count > custom.slots.count) ? Array(sizes.prefix(custom.slots.count)) : sizes
            let availableSlots = custom.effectiveSlots(forCount: effectiveSizes.count)
            guard effectiveSizes.count <= availableSlots.count else { throw ToolError("模板最多支持 \(custom.maxSupportedSlots) 个槽位，当前有 \(effectiveSizes.count) 页。") }
            let rects = availableSlots.prefix(effectiveSizes.count).map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
            let height: Double
            if custom.trimsToContent == true && !config.keepFullTemplateHeight {
                let trimmed = ceil((rects.map(\.maxY).max() ?? 0) + (custom.bottomPadding ?? 0))
                if effectiveSizes.count <= custom.slots.count {
                    height = min(Double(custom.height), trimmed)
                } else {
                    height = trimmed
                }
            } else {
                height = Double(custom.height)
            }
            return (CGSize(width: Double(custom.width), height: height), rects)
        }
        let padding = config.style == .seamless ? 0 : config.padding
        let spacing = config.style == .seamless ? 0 : config.spacing
        let columns = config.style == .grid ? 2 : 1
        let width = (config.width - padding * 2 - spacing * Double(columns - 1)) / Double(columns)
        guard config.width.isFinite, width.isFinite, width > 0, padding >= 0, spacing >= 0 else { throw ToolError("边距过大或画布尺寸无效。") }
        var rects: [CGRect] = []
        var y = padding
        for row in stride(from: 0, to: sizes.count, by: columns) {
            var rowHeight = 0.0
            for col in 0..<columns where row + col < sizes.count {
                let size = sizes[row + col]
                let height = width * size.height / size.width
                rects.append(CGRect(x: padding + Double(col) * (width + spacing), y: y, width: width, height: height))
                rowHeight = max(rowHeight, height)
            }
            y += rowHeight
            if row + columns < sizes.count { y += spacing }
        }
        return (CGSize(width: config.width, height: y + padding), rects)
    }

    // Preserve measured template geometry; snap scaled edges only at output time.
    static func outputSize(reference: CGSize, config: StitchConfig) throws -> CGSize {
        let width = config.custom != nil ? (config.templateOutputWidth ?? reference.width) : reference.width
        guard width.isFinite, width >= 1, width <= 16000, width.rounded() == width,
              reference.width.isFinite, reference.width > 0,
              reference.height.isFinite, reference.height > 0 else {
            throw ToolError("输出宽度必须为 1–16000 之间的整数像素。")
        }
        return CGSize(width: width, height: ceil(reference.height * width / reference.width))
    }

    static func pixelAlignedRects(_ rects: [CGRect], scale: Double) throws -> [CGRect] {
        try rects.map { rect in
            let left = (rect.minX * scale).rounded(), top = (rect.minY * scale).rounded()
            let right = (rect.maxX * scale).rounded(), bottom = (rect.maxY * scale).rounded()
            guard right > left, bottom > top else { throw ToolError("输出宽度过小，无法保留模板图片位置。") }
            return CGRect(x: left, y: top, width: right - left, height: bottom - top)
        }
    }

    static func loadBackgroundImage(named name: String) -> CGImage? {
        let nameWithoutExt = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension.isEmpty ? "png" : (name as NSString).pathExtension

        let tryLoad: (URL?) -> CGImage? = { url in
            guard let url, FileManager.default.fileExists(atPath: url.path),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                return nil
            }
            return cgImage
        }

        // 1. 优先从 Bundle.main / Contents/Resources 中加载（标准独立 App 打包环境，绝不触发 Bundle.module 崩溃）
        if let img = tryLoad(Bundle.main.url(forResource: nameWithoutExt, withExtension: ext, subdirectory: "HeroAssets")) {
            return img
        }
        if let img = tryLoad(Bundle.main.url(forResource: nameWithoutExt, withExtension: ext)) {
            return img
        }
        if let resURL = Bundle.main.resourceURL {
            if let img = tryLoad(resURL.appendingPathComponent("HeroAssets/\(name)")) { return img }
            if let img = tryLoad(resURL.appendingPathComponent(name)) { return img }
            if let img = tryLoad(resURL.appendingPathComponent("PPTTools_PPTTools.bundle/\(name)")) { return img }
            if let img = tryLoad(resURL.appendingPathComponent("PPTTools_PPTTools.bundle/HeroAssets/\(name)")) { return img }
        }

        // 2. 本地开发 / 测试环境回退
        let sourceURL = URL(fileURLWithPath: #filePath)
        let root = sourceURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let localCandidates = [
            root.appendingPathComponent("Templates/PicPark_Hero/assets").appendingPathComponent(name),
            root.appendingPathComponent("Templates/PicPark_RedBook/assets").appendingPathComponent(name),
            root.appendingPathComponent("Sources/PPTTools/Resources/HeroAssets").appendingPathComponent(name)
        ]
        for url in localCandidates {
            if let img = tryLoad(url) {
                return img
            }
        }

        #if SWIFT_PACKAGE
        // 仅在上述途径未找到、且 module bundle 可用时尝试
        let mainBundlePath = Bundle.main.bundleURL.appendingPathComponent("PPTTools_PPTTools.bundle").path
        if FileManager.default.fileExists(atPath: mainBundlePath) {
            if let url = Bundle.module.url(forResource: nameWithoutExt, withExtension: ext, subdirectory: "HeroAssets"), let img = tryLoad(url) {
                return img
            }
            if let url = Bundle.module.url(forResource: nameWithoutExt, withExtension: ext), let img = tryLoad(url) {
                return img
            }
        }
        #endif

        return nil
    }

    static func stitch(_ images: [CGImage], config: StitchConfig, preview: Bool = false) throws -> CGImage {
        var inputImages = images
        let isDetailLong = (config.custom?.id == "picpark-detail-35" || (config.custom != nil && config.custom?.subTemplates == nil && config.custom?.id.contains("hero") != true && config.custom?.id.contains("redbook") != true))
        if isDetailLong && inputImages.count > 1 && inputImages.count % 2 == 0 {
            inputImages = Array(inputImages.dropLast())
        }
        let effectiveImages = (config.custom?.subTemplates != nil && inputImages.count > (config.custom?.slots.count ?? 0)) ? Array(inputImages.prefix(config.custom?.slots.count ?? 0)) : inputImages
        let (size, rects) = try layout(sizes: effectiveImages.map { CGSize(width: $0.width, height: $0.height) }, config: config)
        guard size.width.isFinite, size.height.isFinite, size.height > 0 else { throw ToolError("长图尺寸无效。") }
        let output = try outputSize(reference: size, config: config)
        let previewScale = preview ? min(1, 1400 / output.width, sqrt(6_000_000 / (output.width * output.height)), 24000 / output.height) : 1
        let geometryScale = output.width / size.width
        let pixelRects = try pixelAlignedRects(rects, scale: geometryScale)
        func pixels(_ value: Double) -> Double { (value * geometryScale).rounded() }
        let scale = previewScale
        let context = try context(width: max(1, Int(ceil(output.width * previewScale))), height: max(1, Int(ceil(output.height * previewScale))))
        context.scaleBy(x: scale, y: scale)

        let custom = config.custom
        let isRedBook = (custom?.id == "picpark-redbook" || custom?.id.hasPrefix("picpark-redbook-") == true)
        let isHero6 = (custom?.id == "picpark-hero-6" || custom?.backgroundImageName == "clean_bg_6.png")
        let isHeroBanner = (custom?.id == "picpark-hero")
        let customBgColor: CGColor? = {
            let hex = config.backgroundColorHex ?? custom?.backgroundHex
            if !isRedBook && !isHero6, let hex, !hex.isEmpty {
                return CGColor.fromHex(hex)
            }
            return nil
        }()

        if isHero6 {
            if let bgName = custom?.backgroundImageName, let bgImage = loadBackgroundImage(named: bgName) {
                context.draw(bgImage, in: CGRect(x: 0, y: 0, width: Double(context.width) / scale, height: Double(context.height) / scale))
            }
        } else if let customBg = customBgColor {
            context.setFillColor(customBg)
            context.fill(CGRect(x: 0, y: 0, width: Double(context.width) / scale, height: Double(context.height) / scale))
            if isHeroBanner, let hero6Bg = loadBackgroundImage(named: "clean_bg_6.png") {
                let hero6Rect = CGRect(x: 5500.0 * geometryScale, y: 0, width: 1000.0 * geometryScale, height: 1000.0 * geometryScale)
                context.draw(hero6Bg, in: hero6Rect)
            }
        } else if let bgName = custom?.backgroundImageName, let bgImage = loadBackgroundImage(named: bgName) {
            context.draw(bgImage, in: CGRect(x: 0, y: 0, width: Double(context.width) / scale, height: Double(context.height) / scale))
        } else {
            context.setFillColor(custom?.backgroundColor ?? (config.dark ? CGColor(gray: 0.10, alpha: 1) : CGColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1)))
            // Cover the final integer-sized canvas, including the rounded-up last row.
            context.fill(CGRect(x: 0, y: 0, width: Double(context.width) / scale, height: Double(context.height) / scale))
        }

        context.interpolationQuality = .high
        for (index, topRect) in pixelRects.enumerated() {
            try Task.checkCancellation()
            let rect = CGRect(x: topRect.minX, y: output.height - topRect.maxY, width: topRect.width, height: topRect.height)
            let slot = (custom?.slots.indices.contains(index) == true) ? custom?.slots[index] : nil
            let radius = pixels(slot?.cornerRadius ?? custom?.cornerRadius ?? (config.style == .seamless && custom == nil ? 0 : config.radius))
            let shadow = slot?.shadowOpacity ?? custom?.shadowOpacity ?? (config.style == .seamless ? 0 : config.shadow)
            let shadowBlur = pixels(slot?.shadowBlur ?? 12)
            let shadowOffsetY = pixels(slot?.shadowOffsetY ?? -4)
            let shadowColor: CGColor = {
                let hex = slot?.shadowColorHex ?? custom?.shadowColorHex
                if let hex, let base = CGColor.fromHex(hex) {
                    return base.copy(alpha: shadow) ?? CGColor(gray: 0, alpha: shadow)
                }
                return CGColor(gray: 0, alpha: shadow)
            }()

            let path: CGPath = {
                if let radii = slot?.cornerRadii, radii.count == 4 {
                    let tl = pixels(radii[0])
                    let tr = pixels(radii[1])
                    let br = pixels(radii[2])
                    let bl = pixels(radii[3])
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: rect.minX + tl, y: rect.maxY))
                    p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.maxY))
                    if tr > 0 {
                        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY - tr), radius: tr)
                    } else {
                        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    }
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + br))
                    if br > 0 {
                        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX - br, y: rect.minY), radius: br)
                    } else {
                        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                    }
                    p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.minY))
                    if bl > 0 {
                        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX, y: rect.minY + bl), radius: bl)
                    } else {
                        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                    }
                    p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - tl))
                    if tl > 0 {
                        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX + tl, y: rect.maxY), radius: tl)
                    } else {
                        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    }
                    p.closeSubpath()
                    return p
                } else {
                    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
                }
            }()
            // Draw the shadow before clipping so it remains outside the card.
            context.saveGState()
            if shadow > 0 { context.setShadow(offset: CGSize(width: 0, height: shadowOffsetY), blur: shadowBlur, color: shadowColor) }
            context.addPath(path); context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fillPath()
            context.restoreGState()
            context.saveGState(); context.addPath(path); context.clip()
            let image = effectiveImages[index]
            let sx = rect.width / Double(image.width), sy = rect.height / Double(image.height)
            // Fill measured clipping shapes without stretching the source page.
            let factor = custom?.imageFit == .fill ? max(sx, sy) : min(sx, sy)
            let fitted = CGRect(x: rect.midX - Double(image.width) * factor / 2, y: rect.midY - Double(image.height) * factor / 2, width: Double(image.width) * factor, height: Double(image.height) * factor)
            context.draw(image, in: fitted)
            context.restoreGState()

            let rawStrokeW = slot?.strokeWidth ?? custom?.strokeWidth ?? 0
            if rawStrokeW > 0 {
                let strokeW = max(1.0, pixels(rawStrokeW))
                let strokeColor = (slot?.strokeColorHex ?? custom?.strokeColorHex).flatMap { CGColor.fromHex($0) } ?? CGColor(gray: 1, alpha: 1)
                context.saveGState()
                context.addPath(path)
                context.setStrokeColor(strokeColor)
                context.setLineWidth(strokeW)
                context.strokePath()
                context.restoreGState()
            }

            if config.pageNumbers {
                let text = NSAttributedString(string: String(format: "%02d", index + 1), attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: max(1, pixels(18)), weight: .medium), .foregroundColor: NSColor.white])
                let line = CTLineCreateWithAttributedString(text)
                context.setFillColor(CGColor(gray: 0, alpha: 0.6))
                context.fill(CGRect(x: rect.maxX - pixels(50), y: rect.minY + pixels(8), width: pixels(40), height: pixels(28)))
                context.textPosition = CGPoint(x: rect.maxX - pixels(44), y: rect.minY + pixels(14))
                CTLineDraw(line, context)
            }
        }
        drawRedBookHeader(in: context, output: output, geometryScale: geometryScale, config: config)
        guard let result = context.makeImage() else { throw ToolError("长图合成失败。") }
        return result
    }

    private static func drawRedBookHeader(in context: CGContext, output: CGSize, geometryScale: Double, config: StitchConfig) {
        guard let custom = config.custom, custom.id == "picpark-redbook" || custom.id == "picpark-redbook-1" else { return }

        let titleText = config.redBookTitle ?? "红苹果设计师求职作品集"
        let subtitleText = config.redBookSubtitle ?? "求职简历丨PPTX格式丨支持修改"

        let maxAvailableWidth = (1200.0 - 71.0) * geometryScale

        if !titleText.isEmpty {
            var fontSize = 80.0 * geometryScale
            let tracking = 3.2 * geometryScale
            let color = NSColor(srgbRed: 0.1333, green: 0.1333, blue: 0.1333, alpha: 1.0)

            func makeTitleLine(size: Double) -> CTLine {
                let font: NSFont = NSFont(name: "DOUYINSANSBOLD-GB", size: size)
                    ?? NSFont(name: "PingFangSC-Heavy", size: size)
                    ?? NSFont.systemFont(ofSize: size, weight: .heavy)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .kern: tracking
                ]
                return CTLineCreateWithAttributedString(NSAttributedString(string: titleText, attributes: attrs))
            }

            var line = makeTitleLine(size: fontSize)
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            if width > maxAvailableWidth && width > 0 {
                fontSize = max(30.0 * geometryScale, fontSize * (maxAvailableWidth / width))
                line = makeTitleLine(size: fontSize)
            }

            let baselineX = 71.0 * geometryScale
            let baselineY = output.height - (135.67 * geometryScale)
            context.saveGState()
            context.textPosition = CGPoint(x: baselineX, y: baselineY)
            CTLineDraw(line, context)
            context.restoreGState()
        }

        if !subtitleText.isEmpty {
            var fontSize = 40.0 * geometryScale
            let tracking = 1.6 * geometryScale
            let color = NSColor(srgbRed: 0.5412, green: 0.5412, blue: 0.5412, alpha: 1.0)

            func makeSubtitleLine(size: Double) -> CTLine {
                let font: NSFont = NSFont(name: "PingFangSC-Regular", size: size)
                    ?? NSFont(name: "PingFangSC-Medium", size: size)
                    ?? NSFont.systemFont(ofSize: size, weight: .medium)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .kern: tracking
                ]
                return CTLineCreateWithAttributedString(NSAttributedString(string: subtitleText, attributes: attrs))
            }

            var line = makeSubtitleLine(size: fontSize)
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            if width > maxAvailableWidth && width > 0 {
                fontSize = max(20.0 * geometryScale, fontSize * (maxAvailableWidth / width))
                line = makeSubtitleLine(size: fontSize)
            }

            let baselineX = 71.0 * geometryScale
            let baselineY = output.height - (216.67 * geometryScale)
            context.saveGState()
            context.textPosition = CGPoint(x: baselineX, y: baselineY)
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }

    static func write(_ image: CGImage, to url: URL, format: ImageFormat, dpi: Double = 72) throws {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, (format == .png ? UTType.png : .jpeg).identifier as CFString, 1, nil) else { throw ToolError("无法创建图片。") }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.94, kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ToolError("图片编码失败。") }
        try (data as Data).write(to: url, options: .atomic)
    }
}
