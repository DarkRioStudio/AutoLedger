import Foundation

public enum HotelFolioTextPDFBuilder: Sendable {
    public static func makePDFData(
        text: String,
        title: String = "Hotel folio email body",
        maxCharacters: Int = 12_000
    ) -> Data {
        let normalizedText = normalizedLines(
            text: text,
            title: title,
            maxCharacters: maxCharacters
        )
        var nextCID = 1
        var mappings: [String] = []
        var content = "BT /F1 11 Tf 50 760 Td 14 TL\n"

        for line in normalizedText {
            guard !line.isEmpty else {
                content += "T*\n"
                continue
            }

            var run = ""
            for character in line {
                let cid = nextCID
                nextCID += 1
                run += fourDigitHex(cid)
                mappings.append("<\(fourDigitHex(cid))> <\(utf16BEHex(String(character)))>")
            }
            content += "<\(run)> Tj T*\n"
        }
        content += "ET"

        let cmap = makeToUnicodeCMap(mappings: mappings)
        let objects = [
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 8 0 R >>",
            "<< /Type /Font /Subtype /Type0 /BaseFont /Helvetica /Encoding /Identity-H /DescendantFonts [5 0 R] /ToUnicode 7 0 R >>",
            "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /Helvetica /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor 6 0 R /DW 600 >>",
            "<< /Type /FontDescriptor /FontName /Helvetica /Flags 32 /FontBBox [-166 -225 1000 931] /ItalicAngle 0 /Ascent 931 /Descent -225 /CapHeight 718 /StemV 80 >>",
            streamObject(cmap),
            streamObject(content)
        ]

        return makePDF(objects: objects)
    }

    private static func normalizedLines(
        text: String,
        title: String,
        maxCharacters: Int
    ) -> [String] {
        let trimmed = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Hotel folio email body"
            : title.trimmingCharacters(in: .whitespacesAndNewlines)
        let capped = String((trimmed.isEmpty ? fallback : trimmed).prefix(max(1, maxCharacters)))
        let lines = capped.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return lines.flatMap { wrapLine($0, maxLength: 72) }
    }

    private static func wrapLine(_ line: String, maxLength: Int) -> [String] {
        let characters = Array(line)
        guard characters.count > maxLength else { return [line] }

        var wrapped: [String] = []
        var index = 0
        while index < characters.count {
            let end = min(index + maxLength, characters.count)
            wrapped.append(String(characters[index..<end]))
            index = end
        }
        return wrapped
    }

    private static func makeToUnicodeCMap(mappings: [String]) -> String {
        let chunks = stride(from: 0, to: mappings.count, by: 100).map { start -> String in
            let end = min(start + 100, mappings.count)
            let body = mappings[start..<end].joined(separator: "\n")
            return "\(end - start) beginbfchar\n\(body)\nendbfchar"
        }
        return """
        /CIDInit /ProcSet findresource begin
        12 dict begin
        begincmap
        /CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
        /CMapName /AutoLedgerUnicode def
        /CMapType 2 def
        1 begincodespacerange
        <0000> <FFFF>
        endcodespacerange
        \(chunks.joined(separator: "\n"))
        endcmap
        CMapName currentdict /CMap defineresource pop
        end
        end
        """
    }

    private static func streamObject(_ content: String) -> String {
        "<< /Length \(content.utf8.count) >>\nstream\n\(content)\nendstream"
    }

    private static func makePDF(objects: [String]) -> Data {
        var pdf = "%PDF-1.7\n"
        var offsets: [Int] = [0]

        for (index, object) in objects.enumerated() {
            offsets.append(pdf.utf8.count)
            pdf += "\(index + 1) 0 obj\n\(object)\nendobj\n"
        }

        let xrefOffset = pdf.utf8.count
        pdf += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
        for offset in offsets.dropFirst() {
            pdf += String(format: "%010d 00000 n \n", offset)
        }
        pdf += "trailer << /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(xrefOffset)\n%%EOF\n"
        return Data(pdf.utf8)
    }

    private static func fourDigitHex(_ value: Int) -> String {
        String(format: "%04X", value)
    }

    private static func utf16BEHex(_ value: String) -> String {
        var result = ""
        for unit in value.utf16 {
            result += String(format: "%04X", unit)
        }
        return result
    }
}
