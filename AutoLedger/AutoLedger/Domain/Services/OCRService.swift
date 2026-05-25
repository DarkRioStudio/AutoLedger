import Foundation
import Vision

public enum OCRServiceError: LocalizedError {
    case loadFailed
    case emptyText

    public var errorDescription: String? {
        switch self {
        case .loadFailed:
            return String(localized: "ocr.error.load_failed")
        case .emptyText:
            return String(localized: "ocr.error.empty_text")
        }
    }
}

/// OCR 识别结果，包含识别文本及单词级置信度指标。
public struct OCRResult: Sendable {
    /// 识别出的全部文本（行间以 "\n" 分隔）
    public let text: String
    /// 所有识别单词中置信度最低值（0–1）；值越低说明截图模糊或字符识别不确定
    public let minimumWordConfidence: Float
}

public struct OCRService: Sendable {
    public init() {}

    /// 识别图片中的文本，同时返回最低单词置信度。
    /// 当 `minimumWordConfidence < 0.75` 时，建议将结果交由 LLM 二次验证金额字段。
    public func recognizeTextWithConfidence(from data: Data) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(data: data)
        try handler.perform([request])

        let candidates = (request.results ?? []).compactMap { $0.topCandidates(1).first }
        let text = candidates
            .map(\.string)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw OCRServiceError.emptyText
        }

        let minConfidence = candidates.map(\.confidence).min() ?? 1.0
        return OCRResult(text: text, minimumWordConfidence: minConfidence)
    }

    /// 仅返回文本的简便方法（置信度不需要时使用）。
    public func recognizeText(from data: Data) throws -> String {
        try recognizeTextWithConfidence(from: data).text
    }
}
