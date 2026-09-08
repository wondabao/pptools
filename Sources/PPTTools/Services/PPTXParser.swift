import Foundation
import CoreText

// Read individual ZIP entries without extracting paths into the filesystem.
struct ZIPReader {
    let url: URL
    let entries: Set<String>
    init(url: URL) throws {
        self.url = url
        let data = try Self.run(["-Z1", url.path], limit: 4_000_000)
        guard let listing = String(data: data, encoding: .utf8) else { throw ToolError("无法读取 PPTX 目录。") }
        let names = listing.split(separator: "\n").map(String.init)
        guard names.count <= 20000, names.contains("ppt/presentation.xml") else { throw ToolError("文件不是有效的 PPTX 演示文稿。") }
        entries = Set(names)
    }
    func read(_ path: String) throws -> Data {
        guard entries.contains(path), !path.contains(".."), !path.hasPrefix("/"),
              path.rangeOfCharacter(from: CharacterSet(charactersIn: "*?[]\\")) == nil
        else { throw ToolError("PPTX 内部资源路径无效：\(path)") }
        return try Self.run(["-p", url.path, path], limit: 32_000_000)
    }
    private static func run(_ arguments: [String], limit: Int) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        var output = Data()
        while let chunk = try pipe.fileHandleForReading.read(upToCount: 65536), !chunk.isEmpty {
            output.append(chunk)
            if output.count > limit {
                process.terminate()
                try? pipe.fileHandleForReading.close()
                process.waitUntilExit()
                throw ToolError("PPTX 资源超过安全读取上限。")
            }
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ToolError("PPTX 解压失败，文件可能已损坏或加密。") }
        return output
    }
}

final class XMLNode {
    let name: String
    let attributes: [String: String]
    var children: [XMLNode] = []
    init(_ name: String, _ attributes: [String: String] = [:]) { self.name = name; self.attributes = attributes }
    func all(_ name: String) -> [XMLNode] { (self.name == name ? [self] : []) + children.flatMap { $0.all(name) } }
}

final class XMLTree: NSObject, XMLParserDelegate {
    let root = XMLNode("root")
    var stack: [XMLNode] = []
    var nodeCount = 0
    static func parse(_ data: Data) throws -> XMLNode {
        let tree = XMLTree()
        tree.stack = [tree.root]
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = tree
        guard parser.parse() else { throw ToolError("PPTX XML 损坏：\(parser.parserError?.localizedDescription ?? "未知错误")") }
        return tree.root
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        nodeCount += 1
        guard stack.count < 128, nodeCount <= 300000 else { parser.abortParsing(); return }
        let node = XMLNode(elementName, attributeDict)
        stack.last?.children.append(node)
        stack.append(node)
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { stack.removeLast() }
}

struct PPTXParser {
    struct Relation { let path: String; let type: String }
    static func relations(_ part: String, zip: ZIPReader) throws -> [String: Relation] {
        let base = (part as NSString).deletingLastPathComponent
        let rel = base + "/_rels/" + (part as NSString).lastPathComponent + ".rels"
        guard zip.entries.contains(rel) else { return [:] }
        let root = try XMLTree.parse(zip.read(rel))
        var result: [String: Relation] = [:]
        for node in root.all("Relationship") where node.attributes["TargetMode"] != "External" {
            guard let id = node.attributes["Id"], let target = node.attributes["Target"] else { continue }
            let path = target.hasPrefix("/") ? String(target.dropFirst()) : base + "/" + target
            var components: [String] = []
            var invalid = false
            for component in (path.removingPercentEncoding ?? path).split(separator: "/") {
                if component == "." { continue }
                if component == ".." {
                    if components.isEmpty { invalid = true; break }
                    components.removeLast()
                } else { components.append(String(component)) }
            }
            guard !invalid else { continue }
            let normalized = components.joined(separator: "/")
            result[id] = Relation(path: normalized, type: node.attributes["Type"] ?? "")
        }
        return result
    }
    static func inspect(_ url: URL, progress: (@Sendable (Double, String) -> Void)? = nil) throws -> FontReport {
        progress?(0.05, "正在解压并读取演示文稿结构…")
        let zip = try ZIPReader(url: url)
        let presentation = try XMLTree.parse(zip.read("ppt/presentation.xml"))
        let rels = try relations("ppt/presentation.xml", zip: zip)
        let slides = presentation.all("sldId").compactMap { node -> String? in
            guard let id = node.attributes["r:id"] else { return nil }
            return rels[id]?.path
        }
        guard !slides.isEmpty, slides.count <= 1000 else { throw ToolError("未找到幻灯片，或页数超过 1000 页。") }
        progress?(0.15, "正在解析母版与内嵌字体…")
        var embedded: [String: [EmbeddedFont]] = [:]
        var warnings: [String] = []
        for item in presentation.all("embeddedFont") {
            guard let name = item.children.first(where: { $0.name == "font" })?.attributes["typeface"] else { continue }
            for style in item.children where style.name != "font" {
                guard let id = style.attributes["r:id"], let path = rels[id]?.path else { continue }
                do { embedded[name, default: []].append(EmbeddedFont(name: name, style: style.name, data: try zip.read(path))) }
                catch { warnings.append("内嵌字体 \(name) 无法读取：\(error.localizedDescription)") }
            }
        }
        var usage: [String: Set<Int>] = [:]
        var cache: [String: XMLNode] = [:]
        func tree(_ path: String) throws -> XMLNode {
            if let value = cache[path] { return value }
            let value = try XMLTree.parse(zip.read(path)); cache[path] = value; return value
        }
        for (index, slide) in slides.enumerated() {
            let p = 0.20 + 0.70 * (Double(index + 1) / Double(slides.count))
            progress?(p, "正在检测第 \(index + 1)/\(slides.count) 页幻灯片字体…")
            var parts = [slide]
            var theme: XMLNode?
            var cursor = slide
            // Follow each slide's actual layout/master/theme relationships.
            for suffix in ["/slideLayout", "/slideMaster", "/theme"] {
                let next = try relations(cursor, zip: zip).values.first { $0.type.hasSuffix(suffix) }?.path
                if let next { cursor = next; parts.append(next); if suffix == "/theme" { theme = try tree(next) } }
            }
            var themeFonts: [String: String] = [:]
            for (group, prefix) in [("majorFont", "+mj"), ("minorFont", "+mn")] {
                if let groupNode = theme?.all(group).first {
                    for (tag, suffix) in [("latin", "lt"), ("ea", "ea"), ("cs", "cs")] {
                        let direct = groupNode.children.first { $0.name == tag }?.attributes["typeface"] ?? ""
                        let fallback = groupNode.children.first { $0.name == "font" && $0.attributes["script"] == "Hans" }?.attributes["typeface"] ?? ""
                        themeFonts[prefix + "-" + suffix] = direct.isEmpty && suffix == "ea" ? fallback : direct
                    }
                }
            }
            for part in parts where !part.contains("/theme/") {
                let root = try tree(part)
                for tag in ["latin", "ea", "cs"] {
                    for node in root.all(tag) {
                        guard let raw = node.attributes["typeface"], !raw.isEmpty else { continue }
                        let name = raw.hasPrefix("+") ? (themeFonts[raw] ?? raw) : raw
                        if !name.isEmpty { usage[name, default: []].insert(index + 1) }
                    }
                }
            }
        }
        for name in embedded.keys where usage[name] == nil { usage[name] = [] }
        progress?(0.95, "正在匹配系统已安装字体…")
        let installed = SystemFontProvider.names()
        let fonts = usage.map { name, pages in FontItem(name: name, pages: pages, installed: SystemFontProvider.contains(name, in: installed), embedded: embedded[name] ?? []) }
            .sorted { a, b in a.installed != b.installed ? !a.installed : a.name.localizedStandardCompare(b.name) == .orderedAscending }
        warnings.append("报告包含各页引用的母版、版式字体声明；声明不一定实际用于可见文字。主题东亚空字体按 Hans 回退，其他文字系统及逐字符回退需人工核对。")
        progress?(1.0, "检测完成")
        return FontReport(pageCount: slides.count, fonts: fonts, warnings: warnings)
    }
}

struct SystemFontProvider {
    static func key(_ name: String) -> String { name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "") }
    static func names() -> Set<String> {
        var names = Set<String>()
        let collection = CTFontCollectionCreateFromAvailableFonts(nil)
        let descriptors = CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []
        for descriptor in descriptors {
            let font = CTFontCreateWithFontDescriptor(descriptor, 0, nil)
            for nameKey in [kCTFontFamilyNameKey, kCTFontFullNameKey, kCTFontPostScriptNameKey] {
                if let name = CTFontCopyName(font, nameKey) { names.insert(key(name as String)) }
                if let name = CTFontCopyLocalizedName(font, nameKey, nil) { names.insert(key(name as String)) }
            }
        }
        return names
    }
    static func contains(_ name: String, in names: Set<String>) -> Bool {
        let aliases = ["微软雅黑": "Microsoft YaHei", "宋体": "SimSun", "黑体": "SimHei", "苹方": "PingFang SC", "等线": "DengXian"]
        return names.contains(key(name)) || aliases[name].map { names.contains(key($0)) } == true
    }
}
