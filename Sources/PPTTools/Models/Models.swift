import AppKit
import SwiftUI

extension CGColor {
    static func fromHex(_ hex: String) -> CGColor? {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let rgb = UInt32(str, radix: 16) else { return nil }
        return CGColor(
            srgbRed: Double((rgb >> 16) & 255) / 255.0,
            green: Double((rgb >> 8) & 255) / 255.0,
            blue: Double(rgb & 255) / 255.0,
            alpha: 1.0
        )
    }

    var hexString: String {
        guard let components = components, components.count >= 3 else { return "#FFFFFF" }
        let r = Int(round(components[0] * 255))
        let g = Int(round(components[1] * 255))
        let b = Int(round(components[2] * 255))
        return String(format: "#%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }
}

extension Color {
    init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let rgb = UInt32(str, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 255) / 255.0,
            green: Double((rgb >> 8) & 255) / 255.0,
            blue: Double(rgb & 255) / 255.0
        )
    }

    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let rgb = UInt32(str, radix: 16) else { return nil }
        self.init(
            srgbRed: Double((rgb >> 16) & 255) / 255.0,
            green: Double((rgb >> 8) & 255) / 255.0,
            blue: Double(rgb & 255) / 255.0,
            alpha: 1.0
        )
    }

    var hexString: String {
        let srgb = self.usingColorSpace(.sRGB) ?? self
        let r = Int(round(srgb.redComponent * 255))
        let g = Int(round(srgb.greenComponent * 255))
        let b = Int(round(srgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }
}

struct ToolError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct EmbeddedFont {
    let name: String
    let style: String
    let data: Data
}

struct FontItem: Identifiable {
    var id: String { name }
    let name: String
    var pages: Set<Int>
    var installed: Bool
    var embedded: [EmbeddedFont]
    var status: String { installed ? "已安装" : embedded.isEmpty ? "缺失" : "已内嵌" }
}

struct FontReport {
    let pageCount: Int
    let fonts: [FontItem]
    let warnings: [String]
    var missing: [FontItem] { fonts.filter { !$0.installed && $0.embedded.isEmpty } }
}

struct TemplateSlot: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    var cornerRadius: Double? = nil
    var cornerRadii: [Double]? = nil // [topLeft, topRight, bottomRight, bottomLeft]
    var shadowOpacity: Double? = nil
    var shadowBlur: Double? = nil
    var shadowOffsetY: Double? = nil
    var shadowColorHex: String? = nil
    var strokeWidth: Double? = nil
    var strokeColorHex: String? = nil

    var maxX: Double { x + width }
    var maxY: Double { y + height }
}

enum TemplateImageFit: String, Codable { case fit, fill }

struct TemplateManifest: Codable, Identifiable {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let slots: [TemplateSlot]
    var backgroundHex: String? = nil
    var cornerRadius: Double? = nil
    var shadowOpacity: Double? = nil
    var shadowColorHex: String? = nil
    var strokeWidth: Double? = nil
    var strokeColorHex: String? = nil
    var imageFit: TemplateImageFit? = nil
    var trimsToContent: Bool? = nil
    var bottomPadding: Double? = nil
    var sourceName: String? = nil
    var backgroundImageName: String? = nil
    var subTemplates: [TemplateManifest]? = nil

    /// Maximum slots supported by this template (up to 100 for repeatable detail templates)
    var maxSupportedSlots: Int {
        if id == "picpark-detail-35" || (slots.count >= 3 && subTemplates == nil) {
            return 100
        }
        return slots.count
    }

    /// Returns slots dynamically generated or expanded up to `count` (capped at maxSupportedSlots)
    func effectiveSlots(forCount count: Int) -> [TemplateSlot] {
        guard count > slots.count, maxSupportedSlots > slots.count else {
            return slots
        }
        let targetCount = min(count, maxSupportedSlots)
        var result = slots
        // Detect row pattern from the last two paired slots
        // Slot 0 is full-width header (16:9). Slots 1 & 2, 3 & 4... are pairs.
        if slots.count >= 3 {
            let lastLeft = slots[slots.count - 2]
            let lastRight = slots[slots.count - 1]
            let prevLeft = slots[slots.count - 4]
            let rowPitch = lastLeft.y - prevLeft.y // usually 536.0
            var currentY = lastLeft.y

            while result.count < targetCount {
                currentY += rowPitch
                result.append(TemplateSlot(
                    x: lastLeft.x,
                    y: currentY,
                    width: lastLeft.width,
                    height: lastLeft.height,
                    cornerRadius: lastLeft.cornerRadius,
                    shadowOpacity: lastLeft.shadowOpacity,
                    shadowBlur: lastLeft.shadowBlur,
                    shadowOffsetY: lastLeft.shadowOffsetY,
                    shadowColorHex: lastLeft.shadowColorHex,
                    strokeWidth: lastLeft.strokeWidth,
                    strokeColorHex: lastLeft.strokeColorHex
                ))
                if result.count < targetCount {
                    result.append(TemplateSlot(
                        x: lastRight.x,
                        y: currentY + (lastRight.y - lastLeft.y),
                        width: lastRight.width,
                        height: lastRight.height,
                        cornerRadius: lastRight.cornerRadius,
                        shadowOpacity: lastRight.shadowOpacity,
                        shadowBlur: lastRight.shadowBlur,
                        shadowOffsetY: lastRight.shadowOffsetY,
                        shadowColorHex: lastRight.shadowColorHex,
                        strokeWidth: lastRight.strokeWidth,
                        strokeColorHex: lastRight.strokeColorHex
                    ))
                }
            }
        }
        return result
    }

    var backgroundColor: CGColor? {
        guard let hex = backgroundHex, let color = CGColor.fromHex(hex) else { return nil }
        return color
    }

    func validate() throws {
        guard !id.isEmpty, !name.isEmpty, width > 0, height > 0,
              width <= 16000, height <= 100000, Double(width) * Double(height) <= 200_000_000,
              !slots.isEmpty, slots.count <= 500 else { throw ToolError("模板画布或槽位数量无效。") }
        if let hex = backgroundHex {
            guard hex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil else { throw ToolError("模板背景色必须为 #RRGGBB。") }
        }
        if let hex = shadowColorHex {
            guard hex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil else { throw ToolError("模板阴影颜色必须为 #RRGGBB。") }
        }
        if let w = strokeWidth {
            guard w.isFinite, w >= 0 else { throw ToolError("模板描边宽度无效。") }
        }
        if let hex = strokeColorHex {
            guard hex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil else { throw ToolError("模板描边颜色必须为 #RRGGBB。") }
        }
        if let radius = cornerRadius {
            guard radius.isFinite, radius >= 0, slots.allSatisfy({ radius <= min($0.width, $0.height) / 2 }) else { throw ToolError("模板圆角无效。") }
        }
        if let opacity = shadowOpacity {
            guard opacity.isFinite, (0...1).contains(opacity) else { throw ToolError("模板阴影浓度无效。") }
        }
        if let padding = bottomPadding {
            guard padding.isFinite, padding >= 0, padding <= Double(height) else { throw ToolError("模板底部边距无效。") }
        }
        for s in slots {
            guard [s.x, s.y, s.width, s.height].allSatisfy({ $0.isFinite }),
                  s.x >= 0, s.y >= 0, s.width > 0, s.height > 0,
                  s.x + s.width <= Double(width), s.y + s.height <= Double(height)
            else { throw ToolError("模板槽位超出画布范围。") }
            if let r = s.cornerRadius {
                guard r.isFinite, r >= 0, r <= min(s.width, s.height) / 2 else { throw ToolError("槽位圆角无效。") }
            }
            if let op = s.shadowOpacity {
                guard op.isFinite, (0...1).contains(op) else { throw ToolError("槽位阴影浓度无效。") }
            }
            if let hex = s.shadowColorHex {
                guard hex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil else { throw ToolError("槽位阴影颜色必须为 #RRGGBB。") }
            }
            if let w = s.strokeWidth {
                guard w.isFinite, w >= 0 else { throw ToolError("槽位描边宽度无效。") }
            }
            if let hex = s.strokeColorHex {
                guard hex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil else { throw ToolError("槽位描边颜色必须为 #RRGGBB。") }
            }
        }
        if let subs = subTemplates {
            for sub in subs {
                try sub.validate()
            }
        }
    }
}

enum LayoutStyle: String, CaseIterable, Identifiable {
    case cards = "质感卡片", seamless = "无缝长图", grid = "双列画册"
    var id: String { rawValue }
}

struct StitchConfig {
    var style: LayoutStyle = .cards
    var width: Double = 1080
    var padding: Double = 36
    var spacing: Double = 24
    var radius: Double = 16
    var shadow: Double = 0.15
    var dark: Bool = false
    var pageNumbers: Bool = false
    var custom: TemplateManifest?
    var keepFullTemplateHeight = false
    var templateOutputWidth: Double? = nil
    var backgroundColorHex: String? = nil
    var redBookTitle: String? = nil
    var redBookSubtitle: String? = nil
}

enum ImageFormat: String, CaseIterable, Identifiable {
    case png = "PNG", jpeg = "JPEG"
    var id: String { rawValue }
    var ext: String { self == .png ? "png" : "jpg" }
}

struct PreviewCardItem: Identifiable, Equatable, @unchecked Sendable {
    let id: Int
    let title: String
    let image: NSImage

    static func == (lhs: PreviewCardItem, rhs: PreviewCardItem) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.image === rhs.image
    }
}
