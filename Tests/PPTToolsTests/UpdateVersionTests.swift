import XCTest
@testable import PPTTools

final class UpdateVersionTests: XCTestCase {
    func testSemanticVersionComparison() {
        XCTAssertTrue(SemanticVersion("0.1.0") < SemanticVersion("0.1.1"))
        XCTAssertTrue(SemanticVersion("0.1.0") < SemanticVersion("0.2.0"))
        XCTAssertTrue(SemanticVersion("0.9.9") < SemanticVersion("1.0.0"))
        XCTAssertTrue(SemanticVersion("0.2.0") > SemanticVersion("0.1.9"))

        // v / V 前缀测试
        XCTAssertEqual(SemanticVersion("v0.1.0"), SemanticVersion("0.1.0"))
        XCTAssertEqual(SemanticVersion("V1.2.3"), SemanticVersion("1.2.3"))
        XCTAssertTrue(SemanticVersion("v0.2.0") > SemanticVersion("0.1.0"))

        // 空白与双位测试
        XCTAssertEqual(SemanticVersion(" 0.1 "), SemanticVersion("0.1.0"))
        XCTAssertTrue(SemanticVersion("1.0") < SemanticVersion("1.0.1"))
    }

    func testGitHubReleaseJSONDecoding() throws {
        let json = """
        {
            "tag_name": "v0.2.0",
            "name": "v0.2.0 - 增强长图导出",
            "body": "- 支持多画板套图\\n- 优化高DPI内存占用",
            "html_url": "https://github.com/wondabao/pptools/releases/tag/v0.2.0",
            "published_at": "2026-09-08T09:00:00Z",
            "assets": [
                {
                    "name": "有用工具-v0.2.0.dmg",
                    "browser_download_url": "https://github.com/wondabao/pptools/releases/download/v0.2.0/有用工具-v0.2.0.dmg",
                    "size": 5600000
                },
                {
                    "name": "checksums.txt",
                    "browser_download_url": "https://github.com/wondabao/pptools/releases/download/v0.2.0/checksums.txt",
                    "size": 128
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let release = try decoder.decode(GitHubRelease.self, from: json)

        XCTAssertEqual(release.tagName, "v0.2.0")
        XCTAssertEqual(release.name, "v0.2.0 - 增强长图导出")
        XCTAssertNotNil(release.dmgAsset)
        XCTAssertEqual(release.dmgAsset?.name, "有用工具-v0.2.0.dmg")
        XCTAssertEqual(release.dmgAsset?.size, 5600000)
    }
}
