import Foundation

public enum LedgerAmountInputParser {
    public static func parse(_ text: String) -> Double? {
        let normalized = normalize(text)
        let allowed = normalized.filter { character in
            character.isNumber || character == "." || character == ","
        }
        guard !allowed.isEmpty else { return nil }

        var decimalText = String(allowed)
        if decimalText.contains(",") && !decimalText.contains(".") {
            decimalText = decimalText.replacingOccurrences(of: ",", with: ".")
        } else {
            decimalText = decimalText.replacingOccurrences(of: ",", with: "")
        }

        guard let amount = Double(decimalText), amount > 0 else { return nil }
        return amount
    }

    private static func normalize(_ text: String) -> String {
        text
            .applyingTransform(.fullwidthToHalfwidth, reverse: false)?
            .replacingOccurrences(of: "．", with: ".")
            .replacingOccurrences(of: "，", with: ",")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? text
    }
}
