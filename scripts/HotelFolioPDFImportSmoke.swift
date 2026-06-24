import AppKit
import CoreGraphics
import Foundation

final class HotelFolioPDFImportSmokeReporter {
    private var failures: [String] = []

    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            print("PASS: \(message)")
        } else {
            failures.append(message)
            print("FAIL: \(message)")
        }
    }

    func finish() -> Never {
        if failures.isEmpty {
            print("Hotel folio PDF import smoke passed.")
            exit(EXIT_SUCCESS)
        }

        print("Hotel folio PDF import smoke failed with \(failures.count) issue(s):")
        for failure in failures {
            print("- \(failure)")
        }
        exit(EXIT_FAILURE)
    }
}

@main
struct HotelFolioPDFImportSmoke {
    static func main() throws {
        let reporter = HotelFolioPDFImportSmokeReporter()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoLedgerHotelFolioSmoke-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let pdfURL = root.appendingPathComponent("demo-hotel-folio.pdf")
        try makePDF(
            at: pdfURL,
            text: """
            Demo Bay Hotel
            Confirmation: ABC123
            Check In: 2026-06-20
            Check Out: 2026-06-22
            Total Amount: JPY 50000
            """
        )

        let fixedNow = Date(timeIntervalSince1970: 1_783_065_600)
        let importer = HotelFolioManualPDFImporter(now: { fixedNow })
        let draft = try? importer.importPDF(at: pdfURL, targetLedgerID: TodaySpendingSummary.defaultLedgerID)
        reporter.check(draft?.sourceType == .manualPDF, "HotelFolioManualPDFImporter records manual PDF source")
        reporter.check(draft?.sourceFileName == "demo-hotel-folio.pdf", "HotelFolioManualPDFImporter records source file name")
        reporter.check(draft?.targetLedgerID == TodaySpendingSummary.defaultLedgerID, "HotelFolioManualPDFImporter records target ledger")
        reporter.check(draft?.status == .textExtracted, "HotelFolioManualPDFImporter marks text extracted status")
        reporter.check(draft?.createdAt == fixedNow && draft?.updatedAt == fixedNow, "HotelFolioManualPDFImporter uses stable timestamps")
        reporter.check(draft?.rawText.contains("Demo Bay Hotel") == true, "HotelFolioManualPDFImporter extracts hotel name text")
        reporter.check(draft?.rawText.contains("JPY 50000") == true, "HotelFolioManualPDFImporter extracts amount text")

        let textURL = root.appendingPathComponent("not-a-pdf.txt")
        try "not a PDF".write(to: textURL, atomically: true, encoding: .utf8)
        do {
            _ = try importer.importPDF(at: textURL)
            reporter.check(false, "HotelFolioManualPDFImporter rejects non-PDF files")
        } catch HotelFolioManualPDFImportError.unsupportedFileType {
            reporter.check(true, "HotelFolioManualPDFImporter rejects non-PDF files")
        } catch {
            reporter.check(false, "HotelFolioManualPDFImporter reports expected non-PDF error")
        }

        let emptyPDFURL = root.appendingPathComponent("empty-hotel-folio.pdf")
        try makePDF(at: emptyPDFURL, text: "")
        do {
            _ = try importer.importPDF(at: emptyPDFURL)
            reporter.check(false, "HotelFolioManualPDFImporter rejects empty PDF text")
        } catch HotelFolioManualPDFImportError.emptyText {
            reporter.check(true, "HotelFolioManualPDFImporter rejects empty PDF text")
        } catch {
            reporter.check(false, "HotelFolioManualPDFImporter reports expected empty PDF error")
        }

        reporter.finish()
    }

    private static func makePDF(at url: URL, text: String) throws {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "HotelFolioPDFImportSmoke", code: 1)
        }

        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16)
        ]
        NSAttributedString(string: text, attributes: attributes)
            .draw(in: CGRect(x: 72, y: 560, width: 468, height: 180))
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
        try data.write(to: url)
    }
}
