import XCTest
import AppKit
@testable import PPTTools

final class PicParkHeroTemplateTests: XCTestCase {
    let project = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    func bundledTemplates() throws -> [TemplateManifest] {
        let url = project.appendingPathComponent("Sources/PPTTools/Resources/templates.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([TemplateManifest].self, from: data)
    }

    func testHeroManifestValidationAndGeometry() throws {
        let bundled = try bundledTemplates()
        let heroTpl = try XCTUnwrap(bundled.first { $0.id == "picpark-hero" })
        try heroTpl.validate()

        XCTAssertEqual(heroTpl.name, "PicPark · 电商主图")
        XCTAssertEqual(heroTpl.width, 6500)
        XCTAssertEqual(heroTpl.height, 1000)
        XCTAssertEqual(heroTpl.slots.count, 24)
        XCTAssertEqual(heroTpl.backgroundImageName, "clean_bg_banner.png")
        XCTAssertEqual(heroTpl.cornerRadius, 20)
        XCTAssertEqual(heroTpl.shadowOpacity, 0.0)
        XCTAssertEqual(heroTpl.slots[0].cornerRadius, 20.0)
        XCTAssertEqual(heroTpl.slots[0].strokeWidth, 15.0)
        XCTAssertEqual(heroTpl.slots[0].strokeColorHex, "#FFFFFF")
        let shadowedSlot = try XCTUnwrap(heroTpl.slots.first { $0.shadowOpacity != nil })
        XCTAssertEqual(shadowedSlot.shadowOpacity, 0.15)
        XCTAssertEqual(shadowedSlot.shadowBlur, 16.0)
        XCTAssertEqual(shadowedSlot.shadowOffsetY, -8.0)

        // Verify the 6 artboards inside subTemplates
        let subs = try XCTUnwrap(heroTpl.subTemplates)
        XCTAssertEqual(subs.count, 6, "主图.psd 内包含精确 6 张主图画板")
        for (i, sub) in subs.enumerated() {
            try sub.validate()
            XCTAssertEqual(sub.width, 1000)
            XCTAssertEqual(sub.height, 1000)
            XCTAssertEqual(sub.backgroundImageName, "clean_bg_\(i + 1).png")
            XCTAssertEqual(sub.slots[0].strokeWidth, 15.0, "主图 \(i + 1) 顶部大图具有 15px 白色描边")
            XCTAssertEqual(sub.slots[0].strokeColorHex, "#FFFFFF")
        }
        XCTAssertEqual(subs[0].slots.count, 7)
        XCTAssertEqual(subs[0].slots[0].cornerRadii, [20.0, 20.0, 0.0, 0.0], "第一张电商主图顶部大卡片仅顶部左右有圆角")
        XCTAssertEqual(heroTpl.slots[0].cornerRadii, [20.0, 20.0, 0.0, 0.0])
        XCTAssertEqual(subs[1].slots.count, 4)
        XCTAssertEqual(subs[5].slots.count, 1)
    }

    func testBackgroundImageAssetLoading() throws {
        for i in 1...6 {
            let bg = ImageEngine.loadBackgroundImage(named: "clean_bg_\(i).png")
            XCTAssertNotNil(bg, "clean_bg_\(i).png 必须能够成功加载")
            XCTAssertEqual(bg?.width, 1000)
            XCTAssertEqual(bg?.height, 1000)
        }
        let bannerBg = ImageEngine.loadBackgroundImage(named: "clean_bg_banner.png")
        XCTAssertNotNil(bannerBg, "clean_bg_banner.png 必须能够成功加载")
        XCTAssertEqual(bannerBg?.width, 6500)
        XCTAssertEqual(bannerBg?.height, 1000)
    }

    func testHeroBannerRenderingWithDemoSlides() throws {
        let bundled = try bundledTemplates()
        let heroTpl = try XCTUnwrap(bundled.first { $0.id == "picpark-hero" })

        // Create 24 dummy slides
        var dummySlides: [CGImage] = []
        for _ in 0..<24 {
            let ctx = try ImageEngine.context(width: 960, height: 540)
            ctx.setFillColor(CGColor(srgbRed: 0.2, green: 0.5, blue: 0.9, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: 960, height: 540))
            dummySlides.append(try XCTUnwrap(ctx.makeImage()))
        }

        var config = StitchConfig()
        config.custom = heroTpl

        let rendered = try ImageEngine.stitch(dummySlides, config: config)
        XCTAssertEqual(rendered.width, 6500)
        XCTAssertEqual(rendered.height, 1000)
    }

    func testHeroBannerPreviewRendering() throws {
        let bundled = try bundledTemplates()
        let heroTpl = try XCTUnwrap(bundled.first { $0.id == "picpark-hero" })

        var dummySlides: [CGImage] = []
        for _ in 0..<3 {
            let ctx = try ImageEngine.context(width: 320, height: 180)
            ctx.setFillColor(CGColor(srgbRed: 0.9, green: 0.4, blue: 0.1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
            dummySlides.append(try XCTUnwrap(ctx.makeImage()))
        }

        var config = StitchConfig()
        config.custom = heroTpl

        let preview = try ImageEngine.stitch(dummySlides, config: config, preview: true)
        XCTAssertLessThanOrEqual(preview.width, 1600)
        XCTAssertGreaterThan(preview.width, 0)
        XCTAssertGreaterThan(preview.height, 0)
    }

    func testHeroTemplateAutoTruncatesOver24Pages() throws {
        let bundled = try bundledTemplates()
        let heroTpl = try XCTUnwrap(bundled.first { $0.id == "picpark-hero" })

        // Create 30 dummy slides (exceeding 24 slots)
        var dummySlides: [CGImage] = []
        for _ in 0..<30 {
            let ctx = try ImageEngine.context(width: 320, height: 180)
            ctx.setFillColor(CGColor(srgbRed: 0.1, green: 0.7, blue: 0.3, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
            dummySlides.append(try XCTUnwrap(ctx.makeImage()))
        }

        var config = StitchConfig()
        config.custom = heroTpl

        // Layout should succeed and yield exactly 24 rects
        let (size, rects) = try ImageEngine.layout(sizes: dummySlides.map { CGSize(width: $0.width, height: $0.height) }, config: config)
        XCTAssertEqual(rects.count, 24)
        XCTAssertEqual(size.width, 6500)
        XCTAssertEqual(size.height, 1000)

        // Stitch should succeed without throwing error
        let rendered = try ImageEngine.stitch(dummySlides, config: config)
        XCTAssertEqual(rendered.width, 6500)
        XCTAssertEqual(rendered.height, 1000)
    }

    func testHeroAndDetailCustomBackgroundColor() throws {
        let bundled = try bundledTemplates()
        let heroTpl = try XCTUnwrap(bundled.first { $0.id == "picpark-hero" })
        let detailTpl = try XCTUnwrap(bundled.first { $0.id == "picpark-detail-35" })

        let ctx = try ImageEngine.context(width: 320, height: 180)
        ctx.setFillColor(CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
        let dummy = try XCTUnwrap(ctx.makeImage())

        // 1. Test Detail page custom background color #FF0000
        var detailConfig = StitchConfig()
        detailConfig.custom = detailTpl
        detailConfig.backgroundColorHex = "#FF0000"
        let renderedDetail = try ImageEngine.stitch([dummy], config: detailConfig)
        let detailData = renderedDetail.dataProvider!.data!
        let detailPtr = CFDataGetBytePtr(detailData)!
        let r1 = detailPtr[0], g1 = detailPtr[1], b1 = detailPtr[2]
        XCTAssertGreaterThan(r1, 240, "Background should be red")
        XCTAssertLessThan(g1, 20)
        XCTAssertLessThan(b1, 20)

        // 2. Test Hero banner custom background color #00FF00
        var heroConfig = StitchConfig()
        heroConfig.custom = heroTpl
        heroConfig.backgroundColorHex = "#00FF00"
        let renderedHero = try ImageEngine.stitch([dummy], config: heroConfig)
        let heroData = renderedHero.dataProvider!.data!
        let heroPtr = CFDataGetBytePtr(heroData)!
        let r2 = heroPtr[0], g2 = heroPtr[1], b2 = heroPtr[2]
        XCTAssertLessThan(r2, 20)
        XCTAssertGreaterThan(g2, 240, "Background should be green")
        XCTAssertLessThan(b2, 20)
    }

    @MainActor
    func testHeroAndRedBookMultiCardPreview() async throws {
        let bundled = try bundledTemplates()
        let heroTpl = try XCTUnwrap(bundled.first { $0.id == "picpark-hero" })
        let redBookTpl = try XCTUnwrap(bundled.first { $0.id == "picpark-redbook" })

        let ctx = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let dummy = try XCTUnwrap(ctx.makeImage())
        let dummySlides = Array(repeating: dummy, count: 34)

        let model = AppModel()
        model.templates = bundled
        model.images = dummySlides

        // 1. Test Hero multi-card preview
        model.templateID = heroTpl.id
        model.selectTemplate()
        try await Task.sleep(for: .milliseconds(700))

        XCTAssertEqual(model.previewCards.count, 6)
        XCTAssertEqual(model.previewCards[0].title, "封面合集")
        XCTAssertEqual(model.previewCards[1].title, "亮点展示一")
        XCTAssertEqual(model.previewCards[5].title, "服务保障")
        XCTAssertEqual(model.previewCardIndex, 0)

        // 2. Test RedBook multi-card preview
        model.templateID = redBookTpl.id
        model.selectTemplate()
        try await Task.sleep(for: .milliseconds(700))

        XCTAssertEqual(model.previewCards.count, 5)
        XCTAssertEqual(model.previewCards[0].title, "封面展示")
        XCTAssertEqual(model.previewCards[1].title, "内页浏览一")
        XCTAssertEqual(model.previewCards[4].title, "尾页与引导")
        XCTAssertEqual(model.previewCardIndex, 0)
    }

    func testHero6ServiceGuaranteeSlotAndFixedContent() throws {
        let bundled = try bundledTemplates()
        let heroTpl = try XCTUnwrap(bundled.first { $0.id == "picpark-hero" })
        let subs = try XCTUnwrap(heroTpl.subTemplates)
        let hero6 = subs[5]

        XCTAssertEqual(hero6.id, "picpark-hero-6")
        XCTAssertEqual(hero6.slots.count, 1, "主图 6 · 服务保障 仅放置 1 张幻灯片")
        XCTAssertEqual(hero6.backgroundImageName, "clean_bg_6.png")

        let slot = hero6.slots[0]
        XCTAssertEqual(round(slot.x), 26.0)
        XCTAssertEqual(round(slot.y), 33.0)
        XCTAssertEqual(round(slot.width), 947.0)
        XCTAssertEqual(round(slot.height), 547.0)
        XCTAssertEqual(slot.cornerRadius, 20.0)

        // Render hero-6 with 1 dummy slide
        let ctx = try ImageEngine.context(width: 960, height: 540)
        ctx.setFillColor(CGColor(srgbRed: 0.8, green: 0.2, blue: 0.2, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 960, height: 540))
        let dummy = try XCTUnwrap(ctx.makeImage())

        var config = StitchConfig()
        config.custom = hero6
        // Even if custom background color is passed, hero-6 should preserve clean_bg_6.png
        config.backgroundColorHex = "#FF0000"

        let rendered = try ImageEngine.stitch([dummy], config: config)
        XCTAssertEqual(rendered.width, 1000)
        XCTAssertEqual(rendered.height, 1000)

        // Check bottom pixel (y near bottom where blue gradient and white text are)
        // clean_bg_6.png has blue gradient at bottom, NOT flat red (#FF0000)
        let data = rendered.dataProvider!.data!
        let ptr = CFDataGetBytePtr(data)!
        // Pixel at bottom area (e.g. x=500, y=900)
        let offset = (900 * rendered.bytesPerRow) + (500 * 4)
        let b = ptr[offset + 2] // Blue channel in RGBA / BGRA
        XCTAssertGreaterThan(b, 150, "Bottom area should retain blue background gradient, not red override")
    }

    func testHero1TopCardOnlyHasTopRoundedCorners() throws {
        let bundled = try bundledTemplates()
        let heroTpl = try XCTUnwrap(bundled.first { $0.id == "picpark-hero" })
        let subs = try XCTUnwrap(heroTpl.subTemplates)
        let hero1 = subs[0]

        XCTAssertEqual(hero1.slots[0].cornerRadii, [20.0, 20.0, 0.0, 0.0])

        // Create 7 dummy slides (all solid green)
        var dummySlides: [CGImage] = []
        for _ in 0..<7 {
            let ctx = try ImageEngine.context(width: 960, height: 540)
            ctx.setFillColor(CGColor(srgbRed: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))
            ctx.fill(CGRect(x: 0, y: 0, width: 960, height: 540))
            dummySlides.append(try XCTUnwrap(ctx.makeImage()))
        }

        var config = StitchConfig()
        config.custom = hero1
        let rendered = try ImageEngine.stitch(dummySlides, config: config)
        XCTAssertEqual(rendered.width, 1000)
        XCTAssertEqual(rendered.height, 1000)

        let data = rendered.dataProvider!.data!
        let ptr = CFDataGetBytePtr(data)!

        func pixelAt(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
            let off = (y * rendered.bytesPerRow) + (x * 4)
            return (ptr[off], ptr[off + 1], ptr[off + 2])
        }

        // Top-left: at x=20, CG y=980 (outside card), background is light gray/blue (r>200, g>200, b>200)
        // Inside slide: x=500, CG y=700 is pure green (r=0, g=255, b=0)
        let insidePixel = pixelAt(x: 500, y: 700)
        XCTAssertEqual(insidePixel.r, 0)
        XCTAssertEqual(insidePixel.g, 255)
        XCTAssertEqual(insidePixel.b, 0)

        // Bottom corners have 0 radius (sharp) while top corners have 20px radius.
        // Let's verify slot 0 cornerRadii definition directly
        XCTAssertEqual(hero1.slots[0].cornerRadii?[0], 20.0, "Top-left radius is 20")
        XCTAssertEqual(hero1.slots[0].cornerRadii?[1], 20.0, "Top-right radius is 20")
        XCTAssertEqual(hero1.slots[0].cornerRadii?[2], 0.0, "Bottom-right radius is 0")
        XCTAssertEqual(hero1.slots[0].cornerRadii?[3], 0.0, "Bottom-left radius is 0")
    }
}
