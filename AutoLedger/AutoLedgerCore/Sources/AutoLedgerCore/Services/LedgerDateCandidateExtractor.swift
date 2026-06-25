import Foundation

public enum LedgerDateCandidateConfidence: String, Codable, Sendable, Equatable {
    case high
    case medium
    case low
}

public struct LedgerDateCandidate: Sendable, Equatable {
    public let date: Date
    public let rawText: String
    public let matchedFormat: String
    public let label: String?
    public let confidence: LedgerDateCandidateConfidence
    public let lineIndex: Int

    public init(
        date: Date,
        rawText: String,
        matchedFormat: String,
        label: String?,
        confidence: LedgerDateCandidateConfidence,
        lineIndex: Int
    ) {
        self.date = date
        self.rawText = rawText
        self.matchedFormat = matchedFormat
        self.label = label
        self.confidence = confidence
        self.lineIndex = lineIndex
    }
}

public struct LedgerDateCandidateExtractor: Sendable {
    private let localeIdentifier: String?
    private let languagePackSet: LedgerRecognitionLanguagePackSet

    public init(localeIdentifier: String? = nil, languagePackSet: LedgerRecognitionLanguagePackSet = .builtIn) {
        self.localeIdentifier = localeIdentifier
        self.languagePackSet = languagePackSet
    }

    public func extractCandidates(from text: String) -> [LedgerDateCandidate] {
        guard let languagePack = languagePackSet.mergedPack(for: localeIdentifier),
              !languagePack.dateFormats.isEmpty else {
            return []
        }

        let lines = text.components(separatedBy: .newlines)
        var candidates: [LedgerDateCandidate] = []
        var seen = Set<String>()

        for (lineIndex, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let matchedLabel = languagePack.dateLabels.first { label in
                line.localizedCaseInsensitiveContains(label)
            }

            for format in languagePack.dateFormats {
                for rawCandidate in rawDateMatches(in: line, pattern: format.pattern) {
                    guard let date = parse(rawCandidate, format: format.pattern) else { continue }
                    let key = "\(format.pattern)|\(rawCandidate)"
                    guard !seen.contains(key) else { continue }
                    seen.insert(key)
                    candidates.append(LedgerDateCandidate(
                        date: date,
                        rawText: rawCandidate,
                        matchedFormat: format.pattern,
                        label: matchedLabel,
                        confidence: matchedLabel == nil ? .medium : .high,
                        lineIndex: lineIndex
                    ))
                }
            }
        }

        return candidates.sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return confidenceRank(lhs.confidence) > confidenceRank(rhs.confidence)
            }
            if lhs.lineIndex != rhs.lineIndex {
                return lhs.lineIndex < rhs.lineIndex
            }
            return lhs.rawText.count > rhs.rawText.count
        }
    }

    private func rawDateMatches(in line: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: regexPattern(for: pattern)) else {
            return []
        }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: line) else { return nil }
            return String(line[range])
        }
    }

    private func regexPattern(for pattern: String) -> String {
        var result = ""
        var index = pattern.startIndex
        while index < pattern.endIndex {
            if pattern[index...].hasPrefix("yyyy") {
                result += #"([12][0-9]{3})"#
                index = pattern.index(index, offsetBy: 4)
            } else if pattern[index...].hasPrefix("MM") {
                result += #"([0-1]?[0-9])"#
                index = pattern.index(index, offsetBy: 2)
            } else if pattern[index...].hasPrefix("M") {
                result += #"([0-1]?[0-9])"#
                index = pattern.index(after: index)
            } else if pattern[index...].hasPrefix("dd") {
                result += #"([0-3]?[0-9])"#
                index = pattern.index(index, offsetBy: 2)
            } else if pattern[index...].hasPrefix("d") {
                result += #"([0-3]?[0-9])"#
                index = pattern.index(after: index)
            } else {
                result += NSRegularExpression.escapedPattern(for: String(pattern[index]))
                index = pattern.index(after: index)
            }
        }
        return result
    }

    private func parse(_ rawValue: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        formatter.dateFormat = format
        return formatter.date(from: rawValue)
    }

    private func confidenceRank(_ confidence: LedgerDateCandidateConfidence) -> Int {
        switch confidence {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}
