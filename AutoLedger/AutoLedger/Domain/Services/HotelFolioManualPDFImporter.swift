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

struct HotelFolioManualPDFImporter {
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    func importPDF(at url: URL, targetLedgerID: String? = nil) throws -> HotelStayDraft {
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
        let text = try extractText(from: url)
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

    func extractText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw HotelFolioManualPDFImportError.cannotOpenPDF
        }

        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw HotelFolioManualPDFImportError.emptyText
        }

        return text
    }

    private func isPDFFile(_ url: URL) -> Bool {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           contentType.conforms(to: .pdf) {
            return true
        }

        return url.pathExtension.lowercased() == "pdf"
    }
}
