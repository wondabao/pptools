import XCTest
@testable import PPTTools

final class PPTXFontReplacerTests: XCTestCase {
    private func createTestPPTX() throws -> (folder: URL, pptxURL: URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PPTXFontTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let files = [
            "ppt/presentation.xml": """
            <p:presentation xmlns:p="urn:p" xmlns:r="urn:r"><p:sldIdLst><p:sldId id="4" r:id="r2"/><p:sldId id="9" r:id="r1"/></p:sldIdLst><p:embeddedFontLst><p:embeddedFont><p:font typeface="EmbeddedTest"/><p:regular r:id="f1"/></p:embeddedFont></p:embeddedFontLst></p:presentation>
            """,
            "ppt/_rels/presentation.xml.rels": """
            <Relationships><Relationship Id="r1" Type="urn/slide" Target="slides/slide1.xml"/><Relationship Id="r2" Type="urn/slide" Target="slides/slide2.xml"/><Relationship Id="f1" Type="urn/font" Target="fonts/font1.fntdata"/></Relationships>
            """,
            "ppt/slides/slide1.xml": "<sld><latin typeface='OnlySecondPage'/><ea typeface='CustomChineseFont'/></sld>",
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

        // Add dummy font data
        let fontURL = folder.appendingPathComponent("ppt/fonts/font1.fntdata")
        try FileManager.default.createDirectory(at: fontURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0, count: 64).write(to: fontURL)

        let pptx = folder.appendingPathComponent("test.pptx")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = folder
        process.arguments = ["-qr", pptx.path, "ppt"]
        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        return (folder, pptx)
    }

    func testSingleFontReplacement() throws {
        let (folder, srcPPTX) = try createTestPPTX()
        defer { try? FileManager.default.removeItem(at: folder) }

        let dstPPTX = folder.appendingPathComponent("replaced_single.pptx")

        let summary = try PPTXFontReplacer.replaceFonts(
            in: srcPPTX,
            destinationURL: dstPPTX,
            mapping: ["OnlySecondPage": "PingFang SC"]
        )

        XCTAssertTrue(summary.totalReplacementsCount >= 1)
        XCTAssertTrue(summary.modifiedFilesCount >= 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dstPPTX.path))

        // Inspect dstPPTX and verify
        let report = try PPTXParser.inspect(dstPPTX)
        XCTAssertFalse(report.fonts.contains { $0.name == "OnlySecondPage" })
        XCTAssertTrue(report.fonts.contains { $0.name == "PingFang SC" })
    }

    func testBatchMultiFontReplacement() throws {
        let (folder, srcPPTX) = try createTestPPTX()
        defer { try? FileManager.default.removeItem(at: folder) }

        let dstPPTX = folder.appendingPathComponent("replaced_batch.pptx")

        let mapping = [
            "CustomChineseFont": "PingFang SC",
            "LayoutFont": "PingFang SC",
            "MasterFont": "PingFang SC"
        ]

        let summary = try PPTXFontReplacer.replaceFonts(
            in: srcPPTX,
            destinationURL: dstPPTX,
            mapping: mapping
        )

        XCTAssertTrue(summary.totalReplacementsCount >= 3)
        XCTAssertTrue(summary.modifiedFilesCount >= 2)

        let report = try PPTXParser.inspect(dstPPTX)
        XCTAssertFalse(report.fonts.contains { $0.name == "CustomChineseFont" })
        XCTAssertFalse(report.fonts.contains { $0.name == "LayoutFont" })
        XCTAssertFalse(report.fonts.contains { $0.name == "MasterFont" })
        XCTAssertTrue(report.fonts.contains { $0.name == "PingFang SC" })
    }

    func testFontReplacementValidationErrors() {
        let nonExistentURL = URL(fileURLWithPath: "/tmp/non_existent_\(UUID().uuidString).pptx")
        let destURL = URL(fileURLWithPath: "/tmp/out_\(UUID().uuidString).pptx")

        XCTAssertThrowsError(try PPTXFontReplacer.replaceFonts(in: nonExistentURL, destinationURL: destURL, mapping: ["A": "B"]))
    }
}
