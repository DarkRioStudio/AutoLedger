import AppKit
import Foundation
import Vision

struct ReceiptOCRService {
    struct Output {
        var text: String
        var minConfidence: Float
        var meanConfidence: Float
        var lineCount: Int
        var durationMs: Int
        var width: Int
        var height: Int
    }

    func recognize(url: URL) async throws -> Output {
        try await Task.detached(priority: .userInitiated) {
            let start = Date()
            guard let image = NSImage(contentsOf: url),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw ReceiptOCRServiceError.imageLoadFailed
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "en-US"]

            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            let candidates = (request.results ?? []).compactMap { $0.topCandidates(1).first }
            let confidences = candidates.map(\.confidence)
            let duration = Int(Date().timeIntervalSince(start) * 1000)

            return Output(
                text: candidates.map(\.string).joined(separator: "\n"),
                minConfidence: confidences.min() ?? 0,
                meanConfidence: confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count),
                lineCount: candidates.count,
                durationMs: duration,
                width: cgImage.width,
                height: cgImage.height
            )
        }.value
    }
}

enum ReceiptOCRServiceError: LocalizedError {
    case imageLoadFailed

    var errorDescription: String? {
        switch self {
        case .imageLoadFailed: "无法读取图片。"
        }
    }
}
