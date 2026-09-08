import XCTest
import AppKit
@testable import PPTTools

final class PicParkRedBookTemplateTests: XCTestCase {
    let project = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    func bundledTemplates() throws -> [TemplateManifest] {
        let url = project.appendingPathComponent("Sources/PPTTools/Resources/templates.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([TemplateManifest].self, from: data)
    }

    func testRedBookManifestValidationAndGeometry() throws {
        let bundled = try bundledTemplates()
        let tpl = try XCTUnwrap(bundled.first { $0.id == "picpark-redbook" })
        try tpl.validate()

        XCTAssertEqual(tpl.name, "PicPark · 小红书卡片（1–34）")
        XCTAssertEqual(tpl.width, 7600)
        XCTAssertEqual(tpl.height, 1920)
        XCTAssertEqual(tpl.slots.count, 34)
        XCTAssertEqual(tpl.backgroundImageName, "redbook_bg_banner.png")
        XCTAssertEqual(tpl.cornerRadius, 20)
        XCTAssertEqual(tpl.shadowOpacity, 0.0)

        // Slot 0 (Cover large card) has corner radius 40 and 4px white stroke
        XCTAssertEqual(tpl.slots[0].cornerRadius, 40.0)
        XCTAssertEqual(tpl.slots[0].shadowOpacity, 0.28)
        XCTAssertEqual(tpl.slots[0].shadowBlur, 50.0)
        XCTAssertEqual(tpl.slots[0].shadowOffsetY, -30.0)
        XCTAssertEqual(tpl.slots[0].shadowColorHex, "#B1C4E9")
        XCTAssertEqual(tpl.slots[0].strokeWidth, 4.0)
        XCTAssertEqual(tpl.slots[0].strokeColorHex, "#FFFFFF")
        XCTAssertEqual(tpl.shadowColorHex, "#B1C4E9")

        // Slot 1 has corner radius 20 and 2px white stroke
        XCTAssertEqual(tpl.slots[1].cornerRadius, 20.0)
        XCTAssertEqual(tpl.slots[1].shadowOpacity, 0.28)
        XCTAssertEqual(tpl.slots[1].shadowColorHex, "#B1C4E9")
        XCTAssertEqual(tpl.slots[1].strokeWidth, 2.0)
        XCTAssertEqual(tpl.slots[1].strokeColorHex, "#FFFFFF")

        // Slot 33 (Last slot in AB 5) has corner radius 40 and 4px white stroke
        XCTAssertEqual(tpl.slots[33].cornerRadius, 40.0)
        XCTAssertEqual(tpl.slots[33].shadowColorHex, "#B1C4E9")
        XCTAssertEqual(tpl.slots[33].strokeWidth, 4.0)
        XCTAssertEqual(tpl.slots[33].strokeColorHex, "#FFFFFF")

        // Sub templates
        let subs = try XCTUnwrap(tpl.subTemplates)
        XCTAssertEqual(subs.count, 5, "小红书v2.0.psd 包含 5 个画板")
        let expectedSlots = [5, 8, 8, 8, 5]
        for (i, sub) in subs.enumerated() {
            try sub.validate()
            XCTAssertEqual(sub.width, 1440)
            XCTAssertEqual(sub.height, 1920)
            XCTAssertEqual(sub.backgroundImageName, "redbook_bg_\(i + 1).png")
            XCTAssertEqual(sub.slots.count, expectedSlots[i])
        }
    }

    func testRedBookBackgroundImageAssets() throws {
        for i in 1...5 {
            let bg = ImageEngine.loadBackgroundImage(named: "redbook_bg_\(i).png")
            XCTAssertNotNil(bg, "redbook_bg_\(i).png 必须能够成功加载")
            XCTAssertEqual(bg?.width, 1440)
            XCTAssertEqual(bg?.height, 1920)
        }
        let bannerBg = ImageEngine.loadBackgroundImage(named: "redbook_bg_banner.png")
        XCTAssertNotNil(bannerBg, "redbook_bg_banner.png 必须能够成功加载")
        XCTAssertEqual(bannerBg?.width, 7600)
        XCTAssertEqual(bannerBg?.height, 1920)
    }

    func testRedBookBannerRenderingAndTruncation() throws {
        let bundled = try bundledTemplates()
        let tpl = try XCTUnwrap(bundled.first { $0.id == "picpark-redbook" })

        // Provide 40 slides (> 34 slots) to test that truncation works cleanly without error
        var dummySlides: [CGImage] = []
        for _ in 0..<40 {
            let ctx = try ImageEngine.context(width: 320, height: 180)
            ctx.setFillColor(CGColor(srgbRed: 0.8, green: 0.2, blue: 0.2, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
            dummySlides.append(try XCTUnwrap(ctx.makeImage()))
        }

        var config = StitchConfig()
        config.custom = tpl

        let rendered = try ImageEngine.stitch(dummySlides, config: config, preview: true)
        XCTAssertGreaterThan(rendered.width, 0)
        XCTAssertGreaterThan(rendered.height, 0)
    }

    func testRedBookSubCardRendering() throws {
        let bundled = try bundledTemplates()
        let tpl = try XCTUnwrap(bundled.first { $0.id == "picpark-redbook" })
        let subs = try XCTUnwrap(tpl.subTemplates)

        var dummySlides: [CGImage] = []
        for _ in 0..<5 {
            let ctx = try ImageEngine.context(width: 640, height: 360)
            ctx.setFillColor(CGColor(srgbRed: 0.1, green: 0.6, blue: 0.8, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
            dummySlides.append(try XCTUnwrap(ctx.makeImage()))
        }

        var config = StitchConfig()
        config.custom = subs[0]

        let card1 = try ImageEngine.stitch(dummySlides, config: config)
        XCTAssertEqual(card1.width, 1440)
        XCTAssertEqual(card1.height, 1920)
    }

    func testRedBookCustomTitleAndSubtitleRendering() throws {
        let bundled = try bundledTemplates()
        let tpl = try XCTUnwrap(bundled.first { $0.id == "picpark-redbook" })
        let subs = try XCTUnwrap(tpl.subTemplates)

        var dummySlides: [CGImage] = []
        for _ in 0..<5 {
            let ctx = try ImageEngine.context(width: 640, height: 360)
            ctx.setFillColor(CGColor(srgbRed: 0.9, green: 0.3, blue: 0.3, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
            dummySlides.append(try XCTUnwrap(ctx.makeImage()))
        }

        var config = StitchConfig()
        config.custom = subs[0]
        config.redBookTitle = "高级UI/UX设计师作品集"
        config.redBookSubtitle = "面试求职 | 精选20套落地项目"

        let card1 = try ImageEngine.stitch(dummySlides, config: config)
        XCTAssertEqual(card1.width, 1440)
        XCTAssertEqual(card1.height, 1920)

        // Test with banner as well
        config.custom = tpl
        let banner = try ImageEngine.stitch(dummySlides, config: config, preview: true)
        XCTAssertGreaterThan(banner.width, 0)
    }
}
