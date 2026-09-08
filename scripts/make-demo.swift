import AppKit
import CoreText
let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let url = folder.appendingPathComponent("演示样稿.pdf")
var box = CGRect(x: 0, y: 0, width: 960, height: 540)
let context = CGContext(url as CFURL, mediaBox: &box, nil)!
for (index, title) in ["让每一页，都恰到好处。", "从文稿到长图，只需几步。", "本地处理，自在分享。"].enumerated() {
    context.beginPDFPage(nil)
    context.setFillColor(CGColor(red: 0.06 + Double(index) * 0.015, green: 0.22, blue: 0.23, alpha: 1))
    context.fill(box)
    context.setFillColor(CGColor(red: 0.36, green: 0.85, blue: 0.7, alpha: 1))
    context.fill(CGRect(x: 60, y: 395, width: 60, height: 6))
    func text(_ string: String, x: Double, y: Double, size: Double, color: NSColor) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color]))
        context.textPosition = CGPoint(x: x, y: y); CTLineDraw(line, context)
    }
    text("PPTTOOLS / 有用工具", x: 60, y: 435, size: 18, color: .white)
    text(title, x: 60, y: 260, size: 42, color: .white)
    text("字体检测  /  高清分页  /  详情长图", x: 60, y: 195, size: 22, color: .lightGray)
    text(String(format: "%02d", index + 1), x: 830, y: 55, size: 42, color: .white)
    context.endPDFPage()
}
context.closePDF()
print(url.path)
