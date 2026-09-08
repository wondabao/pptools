import AppKit
import Foundation

guard CommandLine.arguments.count >= 3 else {
    print("Usage: make-icon.swift <input.svg> <output.icns>")
    exit(1)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let svgImage = NSImage(contentsOf: inputURL) else {
    print("无法通过 AppKit 解析 SVG: \(inputURL.path)")
    exit(1)
}

let tempIconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
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
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    
    // macOS 官方 HIG 规范：1024 边长画布中，圆角矩形内容区基准为 824x824 (比例 0.824)
    // 留出大约 9.8% ~ 10% 的周围安全内边距与自然阴影空间，使图标与系统其他 App 完全对齐
    let scale: CGFloat = 0.824
    let contentSize = CGFloat(size) * scale
    let originX = (CGFloat(size) - contentSize) / 2.0
    let originY = (CGFloat(size) - contentSize) / 2.0 + (CGFloat(size) * 0.008) // 微量向下偏置阴影
    let rect = NSRect(x: originX, y: originY, width: contentSize, height: contentSize)
    let cornerRadius = contentSize * 0.2237 // Apple macOS 官方连续平滑圆角率
    let squirclePath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    
    if size >= 32 {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
        shadow.shadowOffset = NSSize(width: 0, height: -CGFloat(size) * 0.02)
        shadow.shadowBlurRadius = CGFloat(size) * 0.035
        shadow.set()
        NSColor.black.setFill()
        squirclePath.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    
    NSGraphicsContext.saveGraphicsState()
    squirclePath.addClip()
    svgImage.draw(
        in: rect,
        from: NSRect(origin: .zero, size: svgImage.size),
        operation: .sourceOver,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("生成 PNG 失败: \(name)")
        exit(1)
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
    print("成功生成高质量 macOS icns: \(outputURL.path)")
} else {
    print("iconutil 失败，退出码: \(iconutil.terminationStatus)")
    exit(1)
}
