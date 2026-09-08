import XCTest
import AppKit
import PDFKit
@testable import PPTTools

final class PPTToolsTests: XCTestCase {
    func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    func image(_ color: CGColor, width: Int = 160, height: Int = 90) throws -> CGImage {
        let context = try ImageEngine.context(width: width, height: height)
        context.setFillColor(color); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try XCTUnwrap(context.makeImage())
    }
    func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        let data = image.dataProvider!.data!
        let pointer = CFDataGetBytePtr(data)!
        let offset = y * image.bytesPerRow + x * 4
        return Array(UnsafeBufferPointer(start: pointer + offset, count: 4))
    }
    func testSingleColumnMarginsAndOrder() throws {
        let red = try image(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        let blue = try image(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        var config = StitchConfig(); config.width = 200; config.padding = 20; config.spacing = 10; config.radius = 0; config.shadow = 0
        let (size, rects) = try ImageEngine.layout(sizes: [CGSize(width: 160, height: 90), CGSize(width: 160, height: 90)], config: config)
        XCTAssertEqual(size, CGSize(width: 200, height: 230))
        XCTAssertEqual(rects[0].minY, 20); XCTAssertEqual(rects[1].minY, 120)
        let result = try ImageEngine.stitch([red, blue], config: config)
        XCTAssertGreaterThan(pixel(result, x: 100, y: 50)[0], 240)
        XCTAssertLessThan(pixel(result, x: 100, y: 50)[2], 60)
        XCTAssertGreaterThan(pixel(result, x: 100, y: 160)[2], 240)
        XCTAssertLessThan(pixel(result, x: 100, y: 160)[0], 60)
    }
    func testGridUsesTallestPagePerRow() throws {
        var config = StitchConfig(); config.style = .grid; config.width = 250; config.padding = 20; config.spacing = 10
        let (size, rects) = try ImageEngine.layout(sizes: [CGSize(width: 100, height: 50), CGSize(width: 100, height: 200), CGSize(width: 100, height: 50)], config: config)
        XCTAssertEqual(rects[2].minY, 230); XCTAssertEqual(size.height, 300)
    }
    func testSeamlessRemovesSpacing() throws {
        var config = StitchConfig(); config.width = 160; config.style = .seamless
        let (size, rects) = try ImageEngine.layout(sizes: Array(repeating: CGSize(width: 160, height: 90), count: 2), config: config)
        XCTAssertEqual(size.height, 180); XCTAssertEqual(rects[0].origin, .zero)
    }
    func testTemplateValidationAndCapacity() throws {
        let invalid = TemplateManifest(id: "x", name: "x", width: 100, height: 100, slots: [TemplateSlot(x: 90, y: 0, width: 20, height: 20)])
        XCTAssertThrowsError(try invalid.validate())
        var config = StitchConfig()
        config.custom = TemplateManifest(id: "x", name: "x", width: 100, height: 100, slots: [TemplateSlot(x: 0, y: 0, width: 100, height: 100)])
        XCTAssertThrowsError(try ImageEngine.layout(sizes: Array(repeating: CGSize(width: 10, height: 10), count: 2), config: config))
        XCTAssertThrowsError(try ImageEngine.context(width: 16000, height: 60000))
    }
    func testPDFRenderingAndJPEGExport() throws {
        let folder = try temporaryFolder(), url = folder.appendingPathComponent("test.pdf")
        var box = CGRect(x: 10, y: 20, width: 160, height: 90)
        let context = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, nil))
        for color in [CGColor(red: 1, green: 0, blue: 0, alpha: 1), CGColor(red: 0, green: 0, blue: 1, alpha: 1)] {
            context.beginPDFPage(nil); context.setFillColor(color); context.fill(box); context.endPDFPage()
        }
        context.closePDF()
        let document = try XCTUnwrap(PDFDocument(url: url))
        document.page(at: 1)?.rotation = 90
        XCTAssertTrue(document.write(to: url))
        let images = try ImageEngine.renderPDF(url, dpi: 144)
        XCTAssertEqual(images.count, 2)
        XCTAssertEqual(images[0].width, 320); XCTAssertEqual(images[0].height, 180)
        XCTAssertEqual(images[1].width, 180); XCTAssertEqual(images[1].height, 320)
        XCTAssertGreaterThan(pixel(images[0], x: 100, y: 50)[0], 240)
        XCTAssertLessThan(pixel(images[0], x: 100, y: 50)[2], 60)
        // High-DPI content must fill the image, not remain centered at 1x size.
        XCTAssertLessThan(pixel(images[0], x: 4, y: 4)[2], 60)
        XCTAssertLessThan(pixel(images[0], x: 315, y: 175)[2], 60)
        XCTAssertGreaterThan(pixel(images[1], x: 4, y: 4)[2], 240)
        XCTAssertLessThan(pixel(images[1], x: 4, y: 4)[0], 60)
        let out = folder.appendingPathComponent("page.jpg")
        try ImageEngine.write(images[0], to: out, format: .jpeg, dpi: 144)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: out)))
        XCTAssertEqual(bitmap.pixelsWide, 320)
    }
    func sampleSFNT() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        bytes[1] = 1; bytes[5] = 1
        bytes.replaceSubrange(12..<16, with: Array("name".utf8))
        bytes[23] = 28; bytes[27] = 4
        return Data(bytes)
    }
    func testRawAndEOTFontExtraction() throws {
        let sfnt = sampleSFNT()
        XCTAssertEqual(try EmbeddedFontExtractor.decode(sfnt).1, "ttf")
        var eot = [UInt8](repeating: 0, count: 82)
        let length = eot.count + sfnt.count
        eot[0] = UInt8(length); eot[4] = UInt8(sfnt.count); eot[10] = 1
        eot[34] = 0x4c; eot[35] = 0x50
        eot.append(contentsOf: sfnt)
        XCTAssertEqual(try EmbeddedFontExtractor.decode(Data(eot)).0, sfnt)
        eot[12] = 4
        XCTAssertThrowsError(try EmbeddedFontExtractor.decode(Data(eot)))
        XCTAssertThrowsError(try EmbeddedFontExtractor.decode(Data([0, 1, 0, 0])))
    }
    func testFontAliases() {
        XCTAssertTrue(SystemFontProvider.contains("微软雅黑", in: ["microsoftyahei"]))
        XCTAssertFalse(SystemFontProvider.contains("NotInstalled", in: ["arial"]))
    }
    func testPPTXRelationshipsAndEmbeddedFonts() throws {
        let folder = try temporaryFolder()
        let files = [
            "ppt/presentation.xml": """
            <p:presentation xmlns:p="urn:p" xmlns:r="urn:r"><p:sldIdLst><p:sldId id="4" r:id="r2"/><p:sldId id="9" r:id="r1"/></p:sldIdLst><p:embeddedFontLst><p:embeddedFont><p:font typeface="EmbeddedTest"/><p:regular r:id="f1"/></p:embeddedFont></p:embeddedFontLst></p:presentation>
            """,
            "ppt/_rels/presentation.xml.rels": """
            <Relationships><Relationship Id="r1" Type="urn/slide" Target="slides/slide1.xml"/><Relationship Id="r2" Type="urn/slide" Target="slides/slide2.xml"/><Relationship Id="f1" Type="urn/font" Target="fonts/font1.fntdata"/></Relationships>
            """,
            "ppt/slides/slide1.xml": "<sld><latin typeface='OnlySecondPage'/></sld>",
            "ppt/slides/slide2.xml": "<sld><latin typeface='+mn-lt'/></sld>",
            "ppt/slides/_rels/slide2.xml.rels": "<Relationships><Relationship Id='l1' Type='urn/slideLayout' Target='../slideLayouts/slideLayout1.xml'/></Relationships>",
            "ppt/slideLayouts/slideLayout1.xml": "<layout><ea typeface='LayoutFont'/></layout>",
            "ppt/slideLayouts/_rels/slideLayout1.xml.rels": "<Relationships><Relationship Id='m1' Type='urn/slideMaster' Target='../slideMasters/slideMaster1.xml'/></Relationships>",
            "ppt/slideMasters/slideMaster1.xml": "<master><latin typeface='MasterFont'/></master>",
            "ppt/slideMasters/_rels/slideMaster1.xml.rels": "<Relationships><Relationship Id='t1' Type='urn/theme' Target='../theme/theme1.xml'/></Relationships>",
            "ppt/theme/theme1.xml": "<theme><minorFont><latin typeface='ThemeResolved'/></minorFont></theme>"
        ]
        for (path, xml) in files {
            let url = folder.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(xml.utf8).write(to: url)
        }
        let fontURL = folder.appendingPathComponent("ppt/fonts/font1.fntdata")
        try FileManager.default.createDirectory(at: fontURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try sampleSFNT().write(to: fontURL)
        let zip = folder.appendingPathComponent("sample.pptx")
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/zip"); process.currentDirectoryURL = folder
        process.arguments = ["-qr", zip.path, "ppt"]; try process.run(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        let report = try PPTXParser.inspect(zip)
        XCTAssertEqual(report.pageCount, 2)
        XCTAssertEqual(report.fonts.first { $0.name == "OnlySecondPage" }?.pages, [2])
        XCTAssertEqual(report.fonts.first { $0.name == "ThemeResolved" }?.pages, [1])
        XCTAssertEqual(report.fonts.first { $0.name == "MasterFont" }?.pages, [1])
        XCTAssertEqual(report.fonts.first { $0.name == "EmbeddedTest" }?.status, "已内嵌")
        XCTAssertThrowsError(try ZIPReader(url: zip).read("../private"))

        var progressValues: [Double] = []
        var progressMessages: [String] = []
        _ = try PPTXParser.inspect(zip) { p, msg in
            progressValues.append(p)
            progressMessages.append(msg)
        }
        XCTAssertFalse(progressValues.isEmpty)
        XCTAssertEqual(progressValues.last, 1.0)
        XCTAssertTrue(progressValues.first! < progressValues.last!)
        XCTAssertTrue(progressMessages.contains { $0.contains("检测完成") })
    }
    func testThemedScrollerAndColor() throws {
        let scroller = NSScroller()
        ThemedScrollerHelper.styleScroller(scroller)
        let color = ThemedScrollerHelper.scrollerColor
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Int(round(r * 255)), 0xD9)
        XCTAssertEqual(Int(round(g * 255)), 0xD9)
        XCTAssertEqual(Int(round(b * 255)), 0xD9)
    }
}
