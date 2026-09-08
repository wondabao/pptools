import XCTest
import AppKit
import PDFKit
@testable import PPTTools

final class IntegrationExportTests: XCTestCase {
    let projectURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    
    func testEndToEndDemoPDFToPicParkAndGenericExports() throws {
        let demoPDF = projectURL.appendingPathComponent("build/演示样稿.pdf")
        if !FileManager.default.fileExists(atPath: demoPDF.path) {
            Self.createDemoPDF(at: demoPDF)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: demoPDF.path), "演示样稿.pdf 必须存在")
        
        // 1. Render PDF at 144 DPI
        let images = try ImageEngine.renderPDF(demoPDF, dpi: 144)
        XCTAssertEqual(images.count, 3, "应该成功渲染 3 页")
        XCTAssertEqual(images[0].width, 1920, "960 pt @ 144 DPI = 1920 px")
        XCTAssertEqual(images[0].height, 1080, "540 pt @ 144 DPI = 1080 px")
        
        // 2. Test PicPark_Detail_35 template export
        let templateData = try Data(contentsOf: projectURL.appendingPathComponent("Templates/PicPark_Detail_35/template.json"))
        let template = try JSONDecoder().decode(TemplateManifest.self, from: templateData)
        try template.validate()
        
        var picparkConfig = StitchConfig()
        picparkConfig.custom = template
        let picparkLongImage = try ImageEngine.stitch(images, config: picparkConfig)
        XCTAssertEqual(picparkLongImage.width, 1872, "PicPark 详情页宽度必须为 1872")
        XCTAssertEqual(picparkLongImage.height, 1658, "3 页自适应裁剪高度应为 1658")
        
        // 3. Test File Output
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let pngOut = tempDir.appendingPathComponent("picpark_detail.png")
        try ImageEngine.write(picparkLongImage, to: pngOut, format: .png)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pngOut.path))
        let pngData = try Data(contentsOf: pngOut)
        XCTAssertGreaterThan(pngData.count, 1000)
        
        let jpgOut = tempDir.appendingPathComponent("picpark_detail.jpg")
        try ImageEngine.write(picparkLongImage, to: jpgOut, format: .jpeg, dpi: 144)
        XCTAssertTrue(FileManager.default.fileExists(atPath: jpgOut.path))
        let jpgData = try Data(contentsOf: jpgOut)
        XCTAssertGreaterThan(jpgData.count, 1000)
        
        // 4. Test Generic Cards Style
        var cardsConfig = StitchConfig()
        cardsConfig.style = .cards
        cardsConfig.width = 1080
        cardsConfig.radius = 16
        cardsConfig.shadow = 0.2
        let cardsLongImage = try ImageEngine.stitch(images, config: cardsConfig)
        XCTAssertEqual(cardsLongImage.width, 1080)
        XCTAssertGreaterThan(cardsLongImage.height, 1000)
        
        // 5. Test Generic Seamless Style
        var seamlessConfig = StitchConfig()
        seamlessConfig.style = .seamless
        seamlessConfig.width = 1080
        let seamlessLongImage = try ImageEngine.stitch(images, config: seamlessConfig)
        XCTAssertEqual(seamlessLongImage.width, 1080)
        // 3 pages of 16:9 at 1080 width = 1080 * 9 / 16 * 3 = 607.5 * 3 = 1823 px
        XCTAssertEqual(Double(seamlessLongImage.height), 1823, accuracy: 2.0)

        // 6. Test PicPark Hero Banner & 6 Artboard Output
        let bundled = try JSONDecoder().decode([TemplateManifest].self, from: Data(contentsOf: projectURL.appendingPathComponent("Sources/PPTTools/Resources/templates.json")))
        var heroConfig = StitchConfig()
        let heroManifest = try XCTUnwrap(bundled.first { $0.id == "picpark-hero" })
        heroConfig.custom = heroManifest
        let heroImage = try ImageEngine.stitch(images, config: heroConfig)
        XCTAssertEqual(heroImage.width, 6500)
        XCTAssertEqual(heroImage.height, 1000)

        // Test Artboard 1 rendering
        let subs = try XCTUnwrap(heroManifest.subTemplates)
        XCTAssertEqual(subs.count, 6)
        var artboard1Config = StitchConfig()
        artboard1Config.custom = subs[0]
        let artboard1Image = try ImageEngine.stitch(images, config: artboard1Config)
        XCTAssertEqual(artboard1Image.width, 1000)
        XCTAssertEqual(artboard1Image.height, 1000)

        let heroOutUrl = tempDir.appendingPathComponent("电商主图_01_封面合集.png")
        try ImageEngine.write(artboard1Image, to: heroOutUrl, format: .png)
        XCTAssertTrue(FileManager.default.fileExists(atPath: heroOutUrl.path))
        XCTAssertGreaterThan((try Data(contentsOf: heroOutUrl)).count, 1000)
    }

    private static func createDemoPDF(at url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var box = CGRect(x: 0, y: 0, width: 960, height: 540)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
        for (index, title) in ["让每一页，都恰到好处。", "从文稿到长图，只需几步。", "本地处理，自在分享。"].enumerated() {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(red: 0.06 + Double(index) * 0.015, green: 0.22, blue: 0.23, alpha: 1))
            context.fill(box)
            context.setFillColor(CGColor(red: 0.36, green: 0.85, blue: 0.7, alpha: 1))
            context.fill(CGRect(x: 60, y: 395, width: 60, height: 6))
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: 42, weight: .medium), .foregroundColor: NSColor.white]))
            context.textPosition = CGPoint(x: 60, y: 260)
            CTLineDraw(line, context)
            context.endPDFPage()
        }
        context.closePDF()
    }
}
