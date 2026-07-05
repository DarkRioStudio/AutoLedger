import Foundation
import PDFKit
import UIKit
import Vision

enum HotelFolioPDFTextExtractionProgress: Equatable, Sendable {
    case readingTextLayer(pageCount: Int)
    case textLayerExtracted(characterCount: Int)
    case ocrStarting(pageCount: Int)
    case ocrPage(index: Int, total: Int)
    case ocrCompleted(characterCount: Int)
    case completed(characterCount: Int, usedOCR: Bool)
}

struct HotelFolioPDFTextExtractionResult: Equatable, Sendable {
    var textLayerText: String
    var ocrText: String
    var combinedText: String
    var didRunOCR: Bool
}

enum HotelFolioPDFTextExtractorError: LocalizedError, Equatable, Sendable {
    case cannotOpenPDF
    case emptyText

    var errorDescription: String? {
        switch self {
        case .cannotOpenPDF:
            return String(localized: "hotel_folio.import.error.cannot_open_pdf")
        case .emptyText:
            return String(localized: "hotel_folio.import.error.empty_text")
        }
    }
}

struct HotelFolioPDFTextExtractor: Sendable {
    private let recognitionLanguages: [String]
    private let maxOCRPageCount: Int

    nonisolated init(
        recognitionLanguages: [String] = ["zh-Hans", "zh-Hant", "en-US", "ja-JP", "ko-KR"],
        maxOCRPageCount: Int = 3
    ) {
        self.recognitionLanguages = recognitionLanguages
        self.maxOCRPageCount = max(1, maxOCRPageCount)
    }

    nonisolated func extractText(
        from data: Data,
        onProgress: @Sendable (HotelFolioPDFTextExtractionProgress) -> Void = { _ in }
    ) throws -> HotelFolioPDFTextExtractionResult {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw HotelFolioPDFTextExtractorError.cannotOpenPDF
        }
        return try extractText(from: document, onProgress: onProgress)
    }

    nonisolated func extractText(
        from url: URL,
        onProgress: @Sendable (HotelFolioPDFTextExtractionProgress) -> Void = { _ in }
    ) throws -> HotelFolioPDFTextExtractionResult {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw HotelFolioPDFTextExtractorError.cannotOpenPDF
        }
        return try extractText(from: document, onProgress: onProgress)
    }

    nonisolated private func extractText(
        from document: PDFDocument,
        onProgress: @Sendable (HotelFolioPDFTextExtractionProgress) -> Void
    ) throws -> HotelFolioPDFTextExtractionResult {
        onProgress(.readingTextLayer(pageCount: document.pageCount))
        let textLayerText = Self.textLayerText(from: document)
        onProgress(.textLayerExtracted(characterCount: textLayerText.count))

        var recognizedOCRText = ""
        var didRunOCR = false
        if shouldRunOCR(textLayerText: textLayerText) {
            didRunOCR = true
            let ocrPageCount = min(document.pageCount, maxOCRPageCount)
            onProgress(.ocrStarting(pageCount: ocrPageCount))
            recognizedOCRText = try ocrText(from: document, pageCount: ocrPageCount, onProgress: onProgress)
            onProgress(.ocrCompleted(characterCount: recognizedOCRText.count))
        }

        let combinedText = Self.mergedText(textLayerText, recognizedOCRText)
        guard !combinedText.isEmpty else {
            throw HotelFolioPDFTextExtractorError.emptyText
        }
        onProgress(.completed(characterCount: combinedText.count, usedOCR: didRunOCR))
        return HotelFolioPDFTextExtractionResult(
            textLayerText: textLayerText,
            ocrText: recognizedOCRText,
            combinedText: combinedText,
            didRunOCR: didRunOCR
        )
    }

    nonisolated private func shouldRunOCR(textLayerText: String) -> Bool {
        let trimmed = textLayerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        guard trimmed.count >= 600 else { return true }

        let lowercased = trimmed.lowercased()
        let hotelSignals = [
            "hotel", "folio", "resort", "plaza", "inn", "suites",
            "酒店", "宾馆", "賓館", "旅馆", "旅館", "ホテル"
        ]
        return !hotelSignals.contains { lowercased.contains($0.lowercased()) }
    }

    nonisolated private func ocrText(
        from document: PDFDocument,
        pageCount: Int,
        onProgress: @Sendable (HotelFolioPDFTextExtractionProgress) -> Void
    ) throws -> String {
        var lines: [String] = []
        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            onProgress(.ocrPage(index: pageIndex + 1, total: pageCount))
            guard let imageData = Self.renderImageData(from: page) else { continue }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = recognitionLanguages

            let handler = VNImageRequestHandler(data: imageData)
            try handler.perform([request])
            let pageLines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            lines.append(contentsOf: pageLines)
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func textLayerText(from document: PDFDocument) -> String {
        (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func renderImageData(from page: PDFPage) -> Data? {
        let pageBounds = page.bounds(for: .mediaBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return nil }
        let scale: CGFloat = 2.4
        let renderSize = CGSize(width: pageBounds.width * scale, height: pageBounds.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: renderSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: renderSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            context.cgContext.translateBy(x: -pageBounds.origin.x, y: -pageBounds.origin.y)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
        return image.pngData()
    }

    nonisolated private static func mergedText(_ textLayerText: String, _ ocrText: String) -> String {
        var seen: Set<String> = []
        var lines: [String] = []
        for line in (textLayerText + "\n" + ocrText).components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .lowercased()
            guard seen.insert(key).inserted else { continue }
            lines.append(trimmed)
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
