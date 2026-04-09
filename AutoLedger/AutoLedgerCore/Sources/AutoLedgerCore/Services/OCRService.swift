import Foundation
import Vision

public enum OCRServiceError: LocalizedError {
    case loadFailed
    case emptyText

    public var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "未能读取所选图片，请换一张截图再试。"
        case .emptyText:
            return "OCR 没识别到文本，请确认截图清晰且包含支付结果信息。"
        }
    }
}

public struct OCRService: Sendable {
    public init() {}

    public func recognizeText(from data: Data) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(data: data)
        try handler.perform([request])

        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw OCRServiceError.emptyText
        }

        return text
    }
}
