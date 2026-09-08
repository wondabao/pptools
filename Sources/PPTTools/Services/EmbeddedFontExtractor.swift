import Foundation

struct EmbeddedFontExtractor {
    static func decode(_ data: Data) throws -> (Data, String) {
        func signature(_ bytes: Data) -> String? {
            let head = Array(bytes.prefix(4))
            if head == [0, 1, 0, 0] || head == Array("true".utf8) { return "ttf" }
            if head == Array("OTTO".utf8) { return "otf" }
            return nil
        }
        func validSFNT(_ bytes: Data) -> Bool {
            let bytes = Array(bytes)
            guard bytes.count >= 12 else { return false }
            let count = Int(bytes[4]) * 256 + Int(bytes[5])
            guard count > 0, count <= 4096, bytes.count >= 12 + count * 16 else { return false }
            func u32(_ p: Int) -> UInt64 { bytes[p..<p+4].reduce(0) { ($0 << 8) | UInt64($1) } }
            for i in 0..<count {
                let p = 12 + i * 16
                if u32(p + 8) + u32(p + 12) > UInt64(bytes.count) { return false }
            }
            return true
        }
        if let ext = signature(data), validSFNT(data) { return (data, ext) }
        // PowerPoint commonly uses an EOT container, not Word's GUID XOR format.
        let bytes = Array(data)
        guard bytes.count >= 82, bytes[34] == 0x4c, bytes[35] == 0x50 else { throw ToolError("字体不是可识别的 TTF/OTF 或未压缩 EOT，无法可靠提取。") }
        func u32(_ p: Int) -> UInt32 { (0..<4).reduce(0) { $0 | UInt32(bytes[p + $1]) << ($1 * 8) } }
        let length = Int(u32(4)), flags = u32(12)
        guard [0x00010000, 0x00020001, 0x00020002].contains(u32(8)) else { throw ToolError("不支持此 EOT 版本。") }
        guard Int(u32(0)) == bytes.count, length > 0, length <= bytes.count - 82, flags & 0x10000004 == 0 else { throw ToolError("暂不支持压缩或异或编码的 EOT 字体。") }
        let font = Data(data.suffix(length))
        guard let ext = signature(font), validSFNT(font) else { throw ToolError("内嵌字体校验失败，未导出损坏文件。") }
        return (font, ext)
    }
}
