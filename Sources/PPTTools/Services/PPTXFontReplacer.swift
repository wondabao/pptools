import Foundation

public struct PPTXFontReplacer {
    public struct ReplacementSummary: Equatable {
        public let modifiedFilesCount: Int
        public let totalReplacementsCount: Int
        public let replacedFonts: [String: String] // [OldFont: NewFont]

        public init(modifiedFilesCount: Int, totalReplacementsCount: Int, replacedFonts: [String: String]) {
            self.modifiedFilesCount = modifiedFilesCount
            self.totalReplacementsCount = totalReplacementsCount
            self.replacedFonts = replacedFonts
        }
    }

    /// 在 PPTX 演示文稿中替换指定字体并另存为新文件
    /// - Parameters:
    ///   - sourceURL: 源 PPTX 文件 URL
    ///   - destinationURL: 目标输出 PPTX 文件 URL
    ///   - mapping: 字体替换映射字典，例如 ["思源黑体": "PingFang SC", "楷体": "Kaiti SC"]
    ///   - progress: 进度回调 (0.0 ~ 1.0, 状态文案)
    /// - Returns: 替换统计报告
    @discardableResult
    public static func replaceFonts(
        in sourceURL: URL,
        destinationURL: URL,
        mapping: [String: String],
        progress: (@Sendable (Double, String) -> Void)? = nil
    ) throws -> ReplacementSummary {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ToolError("源 PPTX 文件不存在：\(sourceURL.path)")
        }
        guard !mapping.isEmpty else {
            throw ToolError("请指定至少一种待替换的字体。")
        }

        progress?(0.05, "正在准备临时工作区…")

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("PPTTools_FontReplace_\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fm.removeItem(at: tempDir)
        }

        // 1. 解压 PPTX
        progress?(0.15, "正在解压演示文稿内部结构…")
        let unzipProcess = Process()
        unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzipProcess.arguments = ["-q", sourceURL.path, "-d", tempDir.path]
        try unzipProcess.run()
        unzipProcess.waitUntilExit()

        guard unzipProcess.terminationStatus == 0 else {
            throw ToolError("解压 PPTX 失败，文件可能已损坏或受密码保护。")
        }

        // 2. 遍历查找所有 XML / rels 文件
        progress?(0.30, "正在检索需要更新字体的幻灯片、版式与母版…")
        var xmlFiles: [URL] = []
        if let enumerator = fm.enumerator(at: tempDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                if ext == "xml" || ext == "rels" {
                    xmlFiles.append(fileURL)
                }
            }
        }

        guard !xmlFiles.isEmpty else {
            throw ToolError("未在 PPTX 中找到有效的 XML 资源文件。")
        }

        // 3. 执行字体文本与属性替换
        var modifiedFilesCount = 0
        var totalReplacementsCount = 0

        for (index, fileURL) in xmlFiles.enumerated() {
            let p = 0.30 + 0.50 * (Double(index + 1) / Double(xmlFiles.count))
            progress?(p, "正在替换字体声明 (\(index + 1)/\(xmlFiles.count))…")

            guard var content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            var fileModified = false

            for (oldFont, newFont) in mapping {
                guard oldFont != newFont else { continue }

                // 替换属性值：typeface="oldFont" 或 typeface='oldFont'
                let patterns = [
                    (from: "typeface=\"\(oldFont)\"", to: "typeface=\"\(newFont)\""),
                    (from: "typeface='\(oldFont)'", to: "typeface='\(newFont)'")
                ]

                for pattern in patterns {
                    if content.contains(pattern.from) {
                        let occurrences = content.components(separatedBy: pattern.from).count - 1
                        if occurrences > 0 {
                            content = content.replacingOccurrences(of: pattern.from, with: pattern.to)
                            totalReplacementsCount += occurrences
                            fileModified = true
                        }
                    }
                }

                // 处理 XML 转义实体情形
                let escapedOld = escapeXML(oldFont)
                let escapedNew = escapeXML(newFont)
                if escapedOld != oldFont {
                    let escapedPatterns = [
                        (from: "typeface=\"\(escapedOld)\"", to: "typeface=\"\(escapedNew)\""),
                        (from: "typeface='\(escapedOld)'", to: "typeface='\(escapedNew)'")
                    ]
                    for pattern in escapedPatterns {
                        if content.contains(pattern.from) {
                            let occurrences = content.components(separatedBy: pattern.from).count - 1
                            if occurrences > 0 {
                                content = content.replacingOccurrences(of: pattern.from, with: pattern.to)
                                totalReplacementsCount += occurrences
                                fileModified = true
                            }
                        }
                    }
                }

                // 若在 presentation.xml 中遇到已内嵌字体的声明，清理旧内嵌字体标签以允许系统字体正常解析
                if fileURL.lastPathComponent == "presentation.xml" {
                    let embeddedPattern = #"<p:embeddedFont>\s*<p:font\s+typeface=["']"# + NSRegularExpression.escapedPattern(for: newFont) + #"["'][^>]*>.*?</p:embeddedFont>"#
                    if let regex = try? NSRegularExpression(pattern: embeddedPattern, options: [.dotMatchesLineSeparators]) {
                        let newRange = NSRange(location: 0, length: content.utf16.count)
                        let matchCount = regex.numberOfMatches(in: content, options: [], range: newRange)
                        if matchCount > 0 {
                            content = regex.stringByReplacingMatches(in: content, options: [], range: newRange, withTemplate: "")
                            fileModified = true
                        }
                    }
                }
            }

            if fileModified {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                modifiedFilesCount += 1
            }
        }

        // 4. 高保真打包压缩为新 PPTX
        progress?(0.85, "正在将修改后的内容打包为新 PPTX…")

        // 确保目标目录存在，且目标文件可写入
        let destDir = destinationURL.deletingLastPathComponent()
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        try? fm.removeItem(at: destinationURL)

        let zipProcess = Process()
        zipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zipProcess.currentDirectoryURL = tempDir
        zipProcess.arguments = ["-qr", destinationURL.path, "."]
        try zipProcess.run()
        zipProcess.waitUntilExit()

        guard zipProcess.terminationStatus == 0, fm.fileExists(atPath: destinationURL.path) else {
            throw ToolError("重新打包 PPTX 失败。")
        }

        progress?(1.0, "字体替换完成！已更新 \(modifiedFilesCount) 个文件，共 \(totalReplacementsCount) 处字体声明。")

        return ReplacementSummary(
            modifiedFilesCount: modifiedFilesCount,
            totalReplacementsCount: totalReplacementsCount,
            replacedFonts: mapping
        )
    }

    private static func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
