import AutoLedgerCore
import Foundation
import PDFKit

struct HotelFolioCloudCandidatePDFImporter: Sendable {
    private let textExtractor: @Sendable (Data) throws -> String
    private let draftFactory: HotelCloudFolioDraftFactory

    init(
        textExtractor: @escaping @Sendable (Data) throws -> String = HotelFolioCloudCandidatePDFImporter.extractPDFText,
        draftFactory: HotelCloudFolioDraftFactory = HotelCloudFolioDraftFactory()
    ) {
        self.textExtractor = textExtractor
        self.draftFactory = draftFactory
    }

    func makeDraft(
        candidate: CloudHotelFolioCandidate,
        pdfData: Data,
        targetLedgerID: String?
    ) throws -> HotelStayDraft {
        guard candidate.mimeType == "application/pdf" || candidate.attachmentFileName.lowercased().hasSuffix(".pdf") else {
            throw HotelFolioEmailImportError.unsupportedAttachment
        }

        let text = try textExtractor(pdfData)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HotelFolioEmailImportError.emptyPDFText
        }

        return try draftFactory.makeDraft(
            candidate: candidate,
            pdfData: pdfData,
            extractedText: text,
            targetLedgerID: targetLedgerID
        )
    }

    nonisolated private static func extractPDFText(from data: Data) throws -> String {
        guard let document = PDFDocument(data: data) else {
            throw HotelFolioEmailImportError.unsupportedAttachment
        }

        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw HotelFolioEmailImportError.emptyPDFText
        }
        return text
    }
}
