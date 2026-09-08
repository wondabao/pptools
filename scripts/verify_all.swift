import Foundation
import AppKit
import PDFKit
import CoreText

// Set module search paths
let cwd = FileManager.default.currentDirectoryPath
let buildDir = URL(fileURLWithPath: cwd).appendingPathComponent(".build/release")
let appURL = URL(fileURLWithPath: cwd).appendingPathComponent("build/有用工具.app")

print("========================================")
print("  有用工具 (PPTTools) 全面自动化测试脚本  ")
print("========================================")

var passedCount = 0
var failedCount = 0

func assertTest(_ condition: Bool, _ message: String) {
    if condition {
        print("  ✅ [PASS] \(message)")
        passedCount += 1
    } else {
        print("  ❌ [FAIL] \(message)")
        failedCount += 1
    }
}

// 1. Check App bundle existence and codesign
print("\n[测试项 1: 应用打包产物检查]")
assertTest(FileManager.default.fileExists(atPath: appURL.path), "build/有用工具.app 存在")
let execURL = appURL.appendingPathComponent("Contents/MacOS/PPTTools")
assertTest(FileManager.default.fileExists(atPath: execURL.path), "应用主可执行文件存在")
let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
assertTest(FileManager.default.fileExists(atPath: infoPlistURL.path), "Info.plist 存在")
let templateResURL = appURL.appendingPathComponent("Contents/Resources/templates.json")
assertTest(FileManager.default.fileExists(atPath: templateResURL.path), "内置 templates.json 资源存在")

// Verify signature
let signTask = Process()
signTask.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
signTask.arguments = ["--verify", "--deep", "--strict", appURL.path]
try? signTask.run()
signTask.waitUntilExit()
assertTest(signTask.terminationStatus == 0, "codesign 签名验证通过")

// 2. Test PicPark PSD Template File Existence
print("\n[测试项 2: PicPark 桌面模版源文件检查]")
let picParkPath = NSHomeDirectory() + "/Desktop/PicPark"
let picParkFiles = [
    "详情页（1-35）.psd",
    "详情页（1-65）.psd",
    "宽屏PPT（1-20）.psd",
    "小红书v2.0.psd",
    "主图.psd",
    "作品集.psd"
]
for f in picParkFiles {
    let p = (picParkPath as NSString).appendingPathComponent(f)
    assertTest(FileManager.default.fileExists(atPath: p), "PicPark 模版存在: \(f)")
}

// 3. Test PicPark_Detail_35 Template JSON parsing & geometry validation
print("\n[测试项 3: PicPark_Detail_35 模版解析与几何约束测试]")
let templatePath = URL(fileURLWithPath: cwd).appendingPathComponent("Templates/PicPark_Detail_35/template.json")
if let data = try? Data(contentsOf: templatePath),
   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    assertTest(json["id"] as? String == "picpark-detail-35", "模版 ID 正确: picpark-detail-35")
    assertTest(json["width"] as? Double == 1872, "模版宽度精确为 1872px")
    assertTest(json["height"] as? Double == 10234, "模版高度精确为 10234px")
    assertTest(json["backgroundHex"] as? String == "#2457F0", "背景颜色为原 PSD 精确蓝色 #2457F0")
    if let slots = json["slots"] as? [[String: Any]] {
        assertTest(slots.count == 35, "槽位数量精确匹配 35 页")
        let first = slots[0]
        let w = first["width"] as? Double ?? 0
        let h = first["height"] as? Double ?? 0
        assertTest(abs(w / h - 16.0 / 9.0) < 0.001, "顶部封面槽位符合 16:9 比例")
    }
} else {
    assertTest(false, "读取解析 template.json 失败")
}

// 3b. Test PicPark_Hero Template JSON parsing & HeroAssets
print("\n[测试项 3b: PicPark 电商主图模版与资源校验]")
let heroTplPath = URL(fileURLWithPath: cwd).appendingPathComponent("Templates/PicPark_Hero/template.json")
if let data = try? Data(contentsOf: heroTplPath),
   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    assertTest(json["id"] as? String == "picpark-hero", "主图模版 ID 正确: picpark-hero")
    assertTest(json["width"] as? Double == 6500, "主图通栏宽度精确为 6500px")
    assertTest(json["height"] as? Double == 1000, "主图通栏高度精确为 1000px")
    assertTest(json["backgroundImageName"] as? String == "clean_bg_banner.png", "背景切图关联正确: clean_bg_banner.png")
    if let slots = json["slots"] as? [[String: Any]] {
        assertTest(slots.count == 24, "槽位数量精确匹配 24 页")
    }
    if let subs = json["subTemplates"] as? [[String: Any]] {
        assertTest(subs.count == 6, "内置 6 张 1000×1000 主图画板")
    }
} else {
    assertTest(false, "读取解析 PicPark_Hero/template.json 失败")
}

for i in 1...6 {
    let heroAssetURL = appURL.appendingPathComponent("Contents/Resources/HeroAssets/clean_bg_\(i).png")
    assertTest(FileManager.default.fileExists(atPath: heroAssetURL.path), "App 打包内置 clean_bg_\(i).png 存在")
}
let bannerAssetURL = appURL.appendingPathComponent("Contents/Resources/HeroAssets/clean_bg_banner.png")
assertTest(FileManager.default.fileExists(atPath: bannerAssetURL.path), "App 打包内置 clean_bg_banner.png 存在")

// 4. Test PDF demo file rendering
print("\n[测试项 4: 演示样稿 PDF 页面完整性测试]")
let demoPDF = URL(fileURLWithPath: cwd).appendingPathComponent("build/演示样稿.pdf")
if FileManager.default.fileExists(atPath: demoPDF.path),
   let doc = PDFDocument(url: demoPDF) {
    assertTest(doc.pageCount == 3, "演示样稿包含 3 页")
    let page1 = doc.page(at: 0)
    let b = page1?.bounds(for: .mediaBox) ?? .zero
    assertTest(b.width == 960 && b.height == 540, "页面比例为 960x540 (16:9 标准)")
} else {
    assertTest(false, "演示样稿.pdf 无法加载")
}

print("\n========================================")
print("  测试结果汇总: 通过 \(passedCount) 项, 失败 \(failedCount) 项")
print("========================================")

if failedCount > 0 {
    exit(1)
}
