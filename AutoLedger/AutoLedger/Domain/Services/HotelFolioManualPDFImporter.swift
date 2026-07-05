import AutoLedgerCore
import Foundation
import PDFKit
import UniformTypeIdentifiers

enum HotelFolioManualPDFImportError: LocalizedError, Equatable, Sendable {
    case unsupportedFileType
    case cannotOpenPDF
    case emptyText

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return String(localized: "hotel_folio.import.error.unsupported_file")
        case .cannotOpenPDF:
            return String(localized: "hotel_folio.import.error.cannot_open_pdf")
        case .emptyText:
            return String(localized: "hotel_folio.import.error.empty_text")
        }
    }
}

struct HotelFolioManualPDFImporter: Sendable {
    private let now: @Sendable () -> Date
    private let textExtractor: HotelFolioPDFTextExtractor

    nonisolated init(
        now: @escaping @Sendable () -> Date = { Date() },
        textExtractor: HotelFolioPDFTextExtractor = HotelFolioPDFTextExtractor()
    ) {
        self.now = now
        self.textExtractor = textExtractor
    }

    nonisolated func importPDF(
        at url: URL,
        targetLedgerID: String? = nil,
        onProgress: @Sendable (HotelFolioPDFTextExtractionProgress) -> Void = { _ in }
    ) throws -> HotelStayDraft {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard isPDFFile(url) else {
            throw HotelFolioManualPDFImportError.unsupportedFileType
        }

        let pdfData = try Data(contentsOf: url)
        let extractionResult = try textExtractor.extractText(from: pdfData, onProgress: onProgress)
        let text = extractionResult.combinedText
        let timestamp = now()
        return HotelStayDraft(
            sourceType: .manualPDF,
            targetLedgerID: targetLedgerID,
            sourceFileName: url.lastPathComponent,
            sourcePDFData: pdfData,
            sourceEmailSubject: nil,
            sourceEmailFrom: nil,
            rawText: text,
            parsedPayload: nil,
            confidence: 0,
            status: .textExtracted,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    nonisolated func extractText(from url: URL) throws -> String {
        try textExtractor.extractText(from: url).combinedText
    }

    nonisolated private func isPDFFile(_ url: URL) -> Bool {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           contentType.conforms(to: .pdf) {
            return true
        }

        return url.pathExtension.lowercased() == "pdf"
    }
}
