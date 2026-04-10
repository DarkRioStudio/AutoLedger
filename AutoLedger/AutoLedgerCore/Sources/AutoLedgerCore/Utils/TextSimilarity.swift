import Foundation

/// OCR 文本相似度工具，用于去重判断。
public enum TextSimilarity {
    /// 计算两段文本的 Jaccard 相似系数（基于字符级 bigram）。
    ///
    /// 返回值 0.0 ~ 1.0，1.0 表示完全相同。
    /// 阈值建议 ≥ 0.8 视为同一来源。
    public static func jaccard(_ a: String, _ b: String) -> Double {
        let bigramsA = bigrams(a)
        let bigramsB = bigrams(b)
        guard !bigramsA.isEmpty || !bigramsB.isEmpty else { return 1.0 }
        let intersection = bigramsA.intersection(bigramsB).count
        let union = bigramsA.union(bigramsB).count
        guard union > 0 else { return 1.0 }
        return Double(intersection) / Double(union)
    }

    private static func bigrams(_ text: String) -> Set<String> {
        // 去除空白和标点，只保留有意义字符
        let cleaned = text.unicodeScalars
            .filter { CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).inverted.contains($0) }
            .map { Character($0) }
        guard cleaned.count >= 2 else { return Set(cleaned.map { String($0) }) }
        var result = Set<String>()
        for i in 0..<(cleaned.count - 1) {
            result.insert(String([cleaned[i], cleaned[i + 1]]))
        }
        return result
    }
}
