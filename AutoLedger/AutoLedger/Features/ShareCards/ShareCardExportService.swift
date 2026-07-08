import AutoLedgerCore
import SwiftUI
import UIKit

struct MonthlySummaryShareCardData: Identifiable {
    struct CategoryItem: Identifiable {
        let id: String
        let title: String
        let amountText: String
        let percentText: String
        let iconName: String
    }

    let id = UUID()
    let monthLabel: String
    let transactionCountText: String
    let totalAmountText: String
    let categories: [CategoryItem]
    let summary: String
}

struct HotelStayShareCardData: Identifiable {
    let id = UUID()
    let hotelName: String
    let locationText: String
    let dateRangeText: String
    let nightsText: String
    let roomTypeText: String
    let priceText: String
    var reviewText: String

    func replacingReviewText(_ value: String) -> HotelStayShareCardData {
        var copy = self
        copy.reviewText = value
        return copy
    }
}

enum ShareCardExportService {
    enum ExportError: LocalizedError {
        case renderFailed
        case pngEncodingFailed

        var errorDescription: String? {
            switch self {
            case .renderFailed:
                return AppLanguagePreference.localizedString(
                    "share_card.error.render_failed",
                    languageKey: AppLanguagePreference.current.catalogLanguageKey
                )
            case .pngEncodingFailed:
                return AppLanguagePreference.localizedString(
                    "share_card.error.png_failed",
                    languageKey: AppLanguagePreference.current.catalogLanguageKey
                )
            }
        }
    }

    @MainActor
    static func exportPNG<Content: View>(
        fileName: String,
        size: CGSize = CGSize(width: 1080, height: 1350),
        @ViewBuilder content: () -> Content
    ) throws -> URL {
        let renderedContent = content()
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: renderedContent)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1

        guard let image = renderer.uiImage else {
            throw ExportError.renderFailed
        }
        guard let data = image.pngData() else {
            throw ExportError.pngEncodingFailed
        }

        let safeName = sanitizedFileName(fileName)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeName)
            .appendingPathExtension("png")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func sanitizedFileName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let result = String(scalars)
            .split(separator: "-")
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return result.isEmpty ? "autoledger-share-card" : result
    }
}
