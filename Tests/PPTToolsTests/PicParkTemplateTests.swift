import XCTest
import AppKit
@testable import PPTTools

final class PicParkTemplateTests: XCTestCase {
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    func template() throws -> TemplateManifest {
        let data = try Data(contentsOf: project.appendingPathComponent("Templates/PicPark_Detail_35/template.json"))
        return try JSONDecoder().decode(TemplateManifest.self, from: data)
    }
    func testStandaloneAndBundledTemplateAgreeWithPSDGeometry() throws {
        let measured = try template()
        try measured.validate()
        let bundled = try JSONDecoder().decode([TemplateManifest].self, from: Data(contentsOf: project.appendingPathComponent("Sources/PPTTools/Resources/templates.json")))
        let item = try XCTUnwrap(bundled.first { $0.id == measured.id })
        XCTAssertEqual(try JSONEncoder().encode(item).count, try JSONEncoder().encode(measured).count)
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: project.appendingPathComponent("docs/template-measurements/picpark-detail-35-measurements.json"))) as? [String: Any])
        let shapes = try XCTUnwrap(report["slots"] as? [[String: Any]])
        XCTAssertEqual(measured.slots.count, 35)
        XCTAssertEqual(shapes.count, 35)
        for i in 0..<35 {
            let bounds = try XCTUnwrap(shapes[i]["vectorShapeBounds"] as? [Double])
            let anchors = try XCTUnwrap(shapes[i]["vectorPathBounds"] as? [Double])
            let slot = measured.slots[i]
            let actual = [slot.x, slot.y, slot.x + slot.width, slot.y + slot.height]
            let bundledSlot = item.slots[i]
            XCTAssertEqual(slot.x, bundledSlot.x); XCTAssertEqual(slot.y, bundledSlot.y)
            XCTAssertEqual(slot.width, bundledSlot.width); XCTAssertEqual(slot.height, bundledSlot.height)
            for j in 0..<4 {
                XCTAssertEqual(actual[j], bounds[j], accuracy: 0.000002)
                XCTAssertEqual(actual[j], anchors[j], accuracy: 0.002)
            }
        }
        XCTAssertEqual(measured.slots[0].width / measured.slots[0].height, 16.0 / 9, accuracy: 0.000001)
        XCTAssertEqual(measured.slots[2].x - (measured.slots[1].x + measured.slots[1].width), 26)
        XCTAssertEqual(measured.slots[4].x - (measured.slots[3].x + measured.slots[3].width), 26.5)
        XCTAssertEqual(measured.backgroundHex, "#2457F0")
        XCTAssertEqual(measured.cornerRadius, 20)
        XCTAssertEqual(measured.shadowOpacity, 0)
        XCTAssertEqual(item.backgroundHex, measured.backgroundHex)
        XCTAssertEqual(item.cornerRadius, measured.cornerRadius)
        XCTAssertEqual(item.shadowOpacity, measured.shadowOpacity)
        XCTAssertEqual(item.trimsToContent, measured.trimsToContent)
    }
    func testMeasuredTemplateHandlesOneThreeAndThirtyFivePages() throws {
        var config = StitchConfig(); config.custom = try template()
        let size = CGSize(width: 160, height: 90)
        let one = try ImageEngine.layout(sizes: [size], config: config)
        XCTAssertEqual(one.0, CGSize(width: 1872, height: 1113))
        let three = try ImageEngine.layout(sizes: Array(repeating: size, count: 3), config: config)
        XCTAssertEqual(three.0, CGSize(width: 1872, height: 1658))
        XCTAssertEqual(three.1[1].minX, 37.5); XCTAssertEqual(three.1[2].minX, 948.5)
        let thirtyFive = try ImageEngine.layout(sizes: Array(repeating: size, count: 35), config: config)
        XCTAssertEqual(thirtyFive.0, CGSize(width: 1872, height: 10234))
        // Supports up to 100 pages dynamically
        let hundred = try ImageEngine.layout(sizes: Array(repeating: size, count: 100), config: config)
        XCTAssertEqual(hundred.1.count, 100)
        XCTAssertThrowsError(try ImageEngine.layout(sizes: Array(repeating: size, count: 101), config: config))
        config.keepFullTemplateHeight = true
        XCTAssertGreaterThanOrEqual(try ImageEngine.layout(sizes: [size], config: config).0.height, 10234)
    }
    func testMeasuredStyleAndAspectFillRendering() throws {
        var config = StitchConfig(); config.custom = try template()
        // These generic controls must not override the measured source styling.
        config.dark = true; config.radius = 0; config.shadow = 0.4
        let c = try ImageEngine.context(width: 160, height: 90)
        c.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: 160, height: 90))
        let slide = try XCTUnwrap(c.makeImage())
        let output = try ImageEngine.stitch([slide, slide, slide], config: config)
        func rgb(_ x: Int, _ y: Int) -> [UInt8] {
            let data = output.dataProvider!.data!, p = CFDataGetBytePtr(data)!
            let offset = y * output.bytesPerRow + x * 4
            return Array(UnsafeBufferPointer(start: p + offset, count: 3))
        }
        XCTAssertEqual(rgb(10, 10), [36, 87, 240])
        XCTAssertEqual(rgb(100, 70), [255, 0, 0])
        XCTAssertEqual(rgb(38, 51), [36, 87, 240]) // Rounded corner.
        XCTAssertEqual(rgb(940, 1300), [36, 87, 240]) // Column gap.
        XCTAssertEqual(rgb(1200, 1109), [255, 0, 0]) // Filled top edge, no aspect-fit white strip.
        XCTAssertEqual(rgb(100, 1612), [36, 87, 240]) // Source has no drop shadow.
    }
    func test1400PixelOutputScalesGeometryAndExportsExactWidth() throws {
        var config = StitchConfig(); config.custom = try template(); config.templateOutputWidth = 1400
        let context = try ImageEngine.context(width: 160, height: 90)
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 160, height: 90))
        let slide = try XCTUnwrap(context.makeImage())
        let output = try ImageEngine.stitch([slide, slide, slide], config: config)
        XCTAssertEqual(output.width, 1400); XCTAssertEqual(output.height, 1240)
        func rgb(_ x: Int, _ y: Int) -> [UInt8] {
            let data = output.dataProvider!.data!, p = CFDataGetBytePtr(data)!
            let offset = y * output.bytesPerRow + x * 4
            return Array(UnsafeBufferPointer(start: p + offset, count: 3))
        }
        XCTAssertEqual(rgb(27, 200), [36, 87, 240]) // Scaled cover left edge: 28.42 px.
        XCTAssertEqual(rgb(30, 200), [255, 255, 255])
        XCTAssertEqual(rgb(700, 37), [36, 87, 240]) // Scaled top padding: 38.14 px.
        XCTAssertEqual(rgb(700, 40), [255, 255, 255])
        XCTAssertEqual(rgb(29, 39), [36, 87, 240]) // Corner remains rounded at scaled radius.
        XCTAssertEqual(rgb(700, 950), [36, 87, 240]) // Scaled double-column gap.
        XCTAssertEqual(rgb(680, 950), [255, 255, 255])
        XCTAssertEqual(rgb(720, 950), [255, 255, 255])
        XCTAssertEqual(rgb(700, 1239), [36, 87, 240]) // Last rounded-up row is opaque background.
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: destination) }
        try ImageEngine.write(output, to: destination, format: .png)
        let decoded = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: destination)))
        XCTAssertEqual(decoded.pixelsWide, 1400); XCTAssertEqual(decoded.pixelsHigh, 1240)
        let full = try ImageEngine.outputSize(reference: CGSize(width: 1872, height: 10234), config: config)
        XCTAssertEqual(full, CGSize(width: 1400, height: 7654))
        config.templateOutputWidth = 2400
        XCTAssertEqual(try ImageEngine.stitch([slide], config: config).width, 2400)
    }

    func testScaledTemplateSnapsEdgesWithoutAccumulatingRowDrift() throws {
        let measured = try template()
        let reference = measured.slots.map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
        for width in [750.0, 1080, 1400, 1872, 2400] {
            let scale = width / 1872
            let rects = try ImageEngine.pixelAlignedRects(reference, scale: scale)
            for (source, rect) in zip(reference, rects) {
                for value in [rect.minX, rect.minY, rect.width, rect.height] { XCTAssertEqual(value, value.rounded()) }
                XCTAssertLessThanOrEqual(abs(rect.minY - source.minY * scale), 0.5)
                XCTAssertLessThanOrEqual(abs(rect.maxY - source.maxY * scale), 0.5)
                XCTAssertLessThanOrEqual(rect.maxX, width)
            }
            for row in 0..<17 { XCTAssertGreaterThan(rects[2 + row * 2].minX, rects[1 + row * 2].maxX) }
        }
        let output = try ImageEngine.pixelAlignedRects(reference, scale: 1400.0 / 1872)
        XCTAssertEqual(output[0], CGRect(x: 28, y: 38, width: 1344, height: 756))
        XCTAssertThrowsError(try ImageEngine.pixelAlignedRects(reference, scale: 1.0 / 1872))
    }

    func testInvalidOutputWidthsFailWithoutAllocating() throws {
        var config = StitchConfig(); config.custom = try template()
        for width in [0, -1, Double.infinity, Double.nan, 16001, 1400.5] {
            config.templateOutputWidth = width
            XCTAssertThrowsError(try ImageEngine.outputSize(reference: CGSize(width: 1872, height: 1658), config: config))
        }
        config.custom = nil; config.templateOutputWidth = 1400
        XCTAssertEqual(try ImageEngine.outputSize(reference: CGSize(width: 1080, height: 1000), config: config).width, 1080)
    }

    func testRejectsInvalidMeasuredStylingAndKeepsLegacyJSON() throws {
        var measured = try template(); measured.backgroundHex = "blue"
        XCTAssertThrowsError(try measured.validate())
        measured = try template(); measured.cornerRadius = -1
        XCTAssertThrowsError(try measured.validate())
        measured = try template(); measured.shadowOpacity = 1.1
        XCTAssertThrowsError(try measured.validate())
        let legacy = try JSONDecoder().decode(TemplateManifest.self, from: Data(contentsOf: project.appendingPathComponent("examples/two-page-gallery.json")))
        try legacy.validate()
        XCTAssertNil(legacy.backgroundHex)
        XCTAssertNil(legacy.trimsToContent)
    }
}
