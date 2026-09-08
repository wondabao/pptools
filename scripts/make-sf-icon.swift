import AppKit
import Foundation

let outputURL = CommandLine.arguments.count >= 2
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "Sources/PPTTools/Resources/AppIcon.icns")

let symbolName = CommandLine.arguments.count >= 3
    ? CommandLine.arguments[2]
    : "square.stack.3d.up.fill"

print("正在使用 SF Symbol [\(symbolName)] 生成 macOS 原生 AppIcon.icns ...")

let tempIconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon_\(UUID().uuidString).iconset")
try? FileManager.default.removeItem(at: tempIconset)
try FileManager.default.createDirectory(at: tempIconset, withIntermediateDirectories: true)

let targets: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in targets {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("无法创建 GraphicsContext")
    }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    // macOS 官方 HIG 规范：1024 边长画布中，圆角矩形内容区基准为 824x824 (比例 0.824)
    let scale: CGFloat = 0.824
    let contentSize = CGFloat(size) * scale
    let originX = (CGFloat(size) - contentSize) / 2.0
    let originY = (CGFloat(size) - contentSize) / 2.0 + (CGFloat(size) * 0.01) // 微量向下偏置
    let rect = NSRect(x: originX, y: originY, width: contentSize, height: contentSize)
    let cornerRadius = contentSize * 0.2237 // Apple macOS 官方连续平滑圆角率
    let squirclePath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    // 1. 底层 Apple 原生弥散投影
    if size >= 32 {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowOffset = NSSize(width: 0, height: -CGFloat(size) * 0.022)
        shadow.shadowBlurRadius = CGFloat(size) * 0.045
        shadow.set()
        NSColor.black.setFill()
        squirclePath.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    // 2. 剪裁至图标 Squircle
    NSGraphicsContext.saveGraphicsState()
    squirclePath.addClip()

    // 3. 绘制极简中性 Apple 质感渐变背景 (深空灰到微暗黑)
    let topColor = NSColor(srgbRed: 0.18, green: 0.19, blue: 0.21, alpha: 1.0)
    let bottomColor = NSColor(srgbRed: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
    let gradient = NSGradient(starting: bottomColor, ending: topColor)!
    gradient.draw(in: rect, angle: 90)

    // 4. 绘制精致内高光光晕 (Inner radial highlight)
    let highlightColor = NSColor.white.withAlphaComponent(0.06)
    let clearColor = NSColor.white.withAlphaComponent(0.0)
    let radialGradient = NSGradient(starting: highlightColor, ending: clearColor)!
    radialGradient.draw(
        fromCenter: NSPoint(x: rect.midX, y: rect.maxY),
        radius: 0,
        toCenter: NSPoint(x: rect.midX, y: rect.midY),
        radius: contentSize * 0.7,
        options: []
    )

    // 5. 绘制 SF Symbol
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: contentSize * 0.46, weight: .medium)
    if let baseSymbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil),
       let symbolImage = baseSymbol.withSymbolConfiguration(symbolConfig) {
        
        let symbolWidth = contentSize * 0.52
        let symbolHeight = (symbolImage.size.height / symbolImage.size.width) * symbolWidth
        let symbolX = rect.midX - (symbolWidth / 2.0)
        let symbolY = rect.midY - (symbolHeight / 2.0) + (CGFloat(size) * 0.005)
        let symbolRect = NSRect(x: symbolX, y: symbolY, width: symbolWidth, height: symbolHeight)

        // 符号微柔光阴影
        NSGraphicsContext.saveGraphicsState()
        let symbolShadow = NSShadow()
        symbolShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        symbolShadow.shadowOffset = NSSize(width: 0, height: -CGFloat(size) * 0.01)
        symbolShadow.shadowBlurRadius = CGFloat(size) * 0.02
        symbolShadow.set()

        // 绘制白色纯净符号
        symbolImage.draw(
            in: symbolRect,
            from: NSRect(origin: .zero, size: symbolImage.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    // 6. 绘制精致发丝内边框 (1px subtle hairline edge)
    let strokePath = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
    strokePath.lineWidth = max(1.0, CGFloat(size) * 0.002)
    NSColor.white.withAlphaComponent(0.14).setStroke()
    strokePath.stroke()

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("生成 PNG 失败: \(name)")
    }

    let fileURL = tempIconset.appendingPathComponent(name)
    try pngData.write(to: fileURL)
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", tempIconset.path, "-o", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()

try? FileManager.default.removeItem(at: tempIconset)

if iconutil.terminationStatus == 0 {
    print("✅ 成功生成高质量 SF Symbol AppIcon: \(outputURL.path)")
} else {
    print("❌ iconutil 失败，退出码: \(iconutil.terminationStatus)")
    exit(1)
}
