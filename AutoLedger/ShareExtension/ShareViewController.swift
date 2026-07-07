import AutoLedgerCore
import PDFKit
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private enum HotelFolioPDFShareError: LocalizedError {
        case readFailed
        case cannotOpenPDF
        case emptyText

        var errorDescription: String? {
            switch self {
            case .readFailed:
                return String(localized: "share.hotel_folio.error.read_failed")
            case .cannotOpenPDF:
                return String(localized: "share.hotel_folio.error.cannot_open_pdf")
            case .emptyText:
                return String(localized: "share.hotel_folio.error.empty_text")
            }
        }
    }

    private enum NavigationDestination: String, Codable {
        case hotelReviewQueue
    }

    private struct NavigationRequest: Codable {
        let destination: NavigationDestination
        let ledgerID: String?
        let createdAt: Date
    }

    private struct HotelFolioDraftReviewRequest: Codable {
        let draftID: UUID
        let createdAt: Date
    }

    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"
    private static let pendingLedgerCloudPushKey = "pendingIntentLedgerCloudPush"
    private static let defaultWriteLedgerIDKey = "defaultWriteLedgerID"
    private static let hotelFolioDraftReviewKey = "share_pendingHotelFolioDraftReview.v1"
    private static let navigationHandoffKey = "autoLedgerIntentNavigationPendingRequest.v1"

    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusIconView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let statusLabel = UILabel()
    private let statusStack = UIStackView()

    // 已知 bundle ID → ReceiptSource 映射
    private static let bundleSourceMap: [String: String] = [
        "com.tencent.xin": "wechat",
        "com.alipay.iphoneclient": "alipay",
        "com.apple.AppStore": "appStore",
        "com.taobao.taobao4iphone": "taobao",
        "com.taobao.fleamarket": "taobao",
        "me.ele.ios.eleme": "eleme",
        "com.ss.iphone.ugc.Aweme": "douyin",
        "com.unionpay.chsp": "unionPay",
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIconView.tintColor = .systemGreen
        statusIconView.contentMode = .scaleAspectFit
        statusIconView.setContentHuggingPriority(.required, for: .horizontal)
        statusIconView.isHidden = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = String(localized: "share.status.recognizing")
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusStack.axis = .horizontal
        statusStack.alignment = .center
        statusStack.distribution = .fill
        statusStack.spacing = 6
        statusStack.addArrangedSubview(statusIconView)
        statusStack.addArrangedSubview(statusLabel)

        view.addSubview(activityIndicator)
        view.addSubview(statusStack)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            statusStack.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 14),
            statusStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            statusStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
            statusStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusIconView.widthAnchor.constraint(equalToConstant: 22),
            statusIconView.heightAnchor.constraint(equalToConstant: 22),
        ])

        activityIndicator.startAnimating()

        processSharedItem()
    }

    private func processSharedItem() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments
        else {
            finish(message: String(localized: "share.error.no_supported_item"))
            return
        }

        if let pdfProvider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }) {
            processSharedHotelFolioPDF(provider: pdfProvider)
            return
        }

        guard let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else {
            finish(message: String(localized: "share.error.no_supported_item"))
            return
        }

        processSharedImage(provider: provider)
    }

    private func processSharedImage(provider: NSItemProvider) {
        // 尝试从 sourceApplication 获取来源 App
        let sourceApp = (extensionContext?.inputItems.first as? NSExtensionItem)?
            .userInfo?["NSExtensionItemSourceApplicationKey"] as? String

        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] data, error in
            guard let self else { return }

            var imageData: Data?
            if let url = data as? URL {
                imageData = try? Data(contentsOf: url)
            } else if let image = data as? UIImage {
                imageData = image.pngData()
            } else if let d = data as? Data {
                imageData = d
            }

            guard let imageData, !imageData.isEmpty else {
                DispatchQueue.main.async { self.finish(message: String(localized: "share.error.read_image_failed")) }
                return
            }

            // OCR
            let ocrService = OCRService()
            let text: String
            do {
                text = try ocrService.recognizeText(from: imageData)
            } catch {
                let msg = String(format: String(localized: "share.error.ocr_failed_format"), error.localizedDescription)
                DispatchQueue.main.async { self.finish(message: msg) }
                return
            }

            // 来源：优先用 bundle ID 映射，回退到规则推断
            let source: ReceiptSource
            if let bundleID = sourceApp,
               let mapped = Self.bundleSourceMap[bundleID],
               let s = ReceiptSource(rawValue: mapped) {
                source = s
            } else {
                source = ReceiptSource.infer(from: text)
            }

            let parser = ReceiptParser()

            // 解析
            guard let receipt = parser.parse(text: text, source: source, imageData: imageData) else {
                self.writeDebug(stage: .parseFailed, source: source, rawText: text, summary: String(localized: "share.debug.parse_failed"))
                DispatchQueue.main.async { self.finish(message: String(localized: "share.error.recognition_failed")) }
                return
            }

            // 去重 + 入账
            guard let store = try? SQLiteTransactionStore() else {
                DispatchQueue.main.async { self.finish(message: String(localized: "share.error.database_failed")) }
                return
            }
            let receiptForSave = MerchantAliasResolver.applyingAlias(
                to: receipt,
                aliases: (try? store.loadMerchantAliases()) ?? [:],
                categoryCorrections: (try? store.loadCategoryCorrections()) ?? [:],
                contextText: text
            )

            let existing = (try? store.loadTransactions()) ?? []
            let isDuplicate = existing.contains {
                $0.merchant == receiptForSave.merchant &&
                abs($0.amount - receiptForSave.amount) < 0.01 &&
                abs($0.occurredAt.timeIntervalSince(receiptForSave.occurredAt)) < 60
            }

            // OCR 文本 Jaccard 相似度去重
            let isOCRDuplicate: Bool = {
                ImportDuplicateDetector.hasOCRTextDuplicate(
                    rawText: text,
                    debugRecords: (try? store.loadDebugEvents()) ?? [],
                    activeTransactionIDs: Set(existing.map(\.id)),
                    parsedAmount: receiptForSave.amount,
                    threshold: 0.8
                )
            }()

            if isDuplicate || isOCRDuplicate {
                let msg = String(format: String(localized: "share.duplicate_format"), receiptForSave.merchant, receiptForSave.amount)
                self.writeDebug(stage: .duplicateSkipped, source: source, rawText: text, receipt: receiptForSave, summary: msg)
                DispatchQueue.main.async { self.finish(message: msg) }
                return
            }

            let transaction = Transaction(
                merchant: receiptForSave.merchant,
                amount: receiptForSave.amount,
                occurredAt: receiptForSave.occurredAt,
                category: receiptForSave.suggestedCategory,
                source: receiptForSave.source,
                note: String(localized: "share.note")
            )

            do {
                try store.save(transaction: transaction)
                self.markLedgerSaveNeedsCloudPush()
                self.writeShareResult(ocrText: text, receipt: receiptForSave)
                var msg = String(format: String(localized: "share.saved_format"), receiptForSave.merchant, receiptForSave.amount)
                self.writeDebug(stage: .persisted, source: source, rawText: text, receipt: receiptForSave, summary: msg, transactionID: transaction.id)
                DispatchQueue.main.async { self.finish(message: msg, showsSuccessIcon: true) }
            } catch {
                let debugMessage = String(format: String(localized: "share.debug.persistence_failed_format"), error.localizedDescription)
                self.writeDebug(stage: .persistenceFailed, source: source, rawText: text, receipt: receiptForSave, summary: debugMessage)
                DispatchQueue.main.async { self.finish(message: String(localized: "share.error.persistence_failed")) }
            }
        }
    }

    private func processSharedHotelFolioPDF(provider: NSItemProvider) {
        DispatchQueue.main.async {
            self.statusLabel.text = String(localized: "share.hotel_folio.status.extracting")
        }

        provider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { [weak self] url, _ in
            guard let self else { return }

            do {
                let pdfData: Data
                if let url {
                    pdfData = try Data(contentsOf: url)
                } else {
                    pdfData = try self.loadPDFDataFallback(from: provider)
                }

                let rawText = try self.extractHotelFolioText(from: pdfData)
                let draft = self.makeHotelStayDraft(
                    pdfData: pdfData,
                    rawText: rawText,
                    suggestedFileName: provider.suggestedName
                )

                guard let store = try? SQLiteTransactionStore() else {
                    DispatchQueue.main.async { self.finish(message: String(localized: "share.error.database_failed")) }
                    return
                }

                let draftForReview = self.resolveDuplicateDraftIfNeeded(draft, store: store)
                if draftForReview.id == draft.id {
                    try store.save(hotelStayDraft: draft)
                }

                self.markLedgerSaveNeedsCloudPush()
                self.writeHotelFolioReviewHandoff(draft: draftForReview)

                DispatchQueue.main.async {
                    self.finish(
                        message: String(localized: "share.hotel_folio.saved"),
                        openAppURL: Self.hotelReviewURL(draftID: draftForReview.id),
                        showsSuccessIcon: true
                    )
                }
            } catch {
                let message = String(
                    format: String(localized: "share.hotel_folio.error_format"),
                    error.localizedDescription
                )
                DispatchQueue.main.async {
                    self.finish(message: message)
                }
            }
        }
    }

    private func loadPDFDataFallback(from provider: NSItemProvider) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        var loadedData: Data?

        provider.loadDataRepresentation(forTypeIdentifier: UTType.pdf.identifier) { data, _ in
            loadedData = data
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 8)
        guard let loadedData, !loadedData.isEmpty else {
            throw HotelFolioPDFShareError.readFailed
        }
        return loadedData
    }

    private func extractHotelFolioText(from pdfData: Data) throws -> String {
        guard let document = PDFDocument(data: pdfData), document.pageCount > 0 else {
            throw HotelFolioPDFShareError.cannotOpenPDF
        }

        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw HotelFolioPDFShareError.emptyText
        }
        return text
    }

    private func makeHotelStayDraft(
        pdfData: Data,
        rawText: String,
        suggestedFileName: String?
    ) -> HotelStayDraft {
        let timestamp = Date()
        let fileName = normalizedPDFFileName(suggestedFileName)
        return HotelStayDraft(
            sourceType: .shareExtension,
            targetLedgerID: defaultWriteLedgerIDForSharedImports(),
            sourceFileName: fileName,
            sourcePDFData: pdfData,
            rawText: rawText,
            confidence: 0,
            status: .textExtracted,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private func resolveDuplicateDraftIfNeeded(
        _ draft: HotelStayDraft,
        store: SQLiteTransactionStore
    ) -> HotelStayDraft {
        guard let pdfData = draft.sourcePDFData, !pdfData.isEmpty else { return draft }
        let existingDrafts = (try? store.loadHotelStayDrafts()) ?? []
        return existingDrafts.first { existing in
            switch existing.status {
            case .imported, .textExtracted, .parsed, .needsReview:
                return existing.sourcePDFData == pdfData
            case .confirmed, .rejected, .postedToLedger:
                return false
            }
        } ?? draft
    }

    private func defaultWriteLedgerIDForSharedImports() -> String {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier),
              let value = defaults.string(forKey: Self.defaultWriteLedgerIDKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return TodaySpendingSummary.defaultLedgerID
        }
        return value
    }

    private func normalizedPDFFileName(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "shared-hotel-folio.pdf" }
        if trimmed.lowercased().hasSuffix(".pdf") {
            return trimmed
        }
        return "\(trimmed).pdf"
    }

    private func writeHotelFolioReviewHandoff(draft: HotelStayDraft) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else { return }

        let reviewRequest = HotelFolioDraftReviewRequest(draftID: draft.id, createdAt: Date())
        if let data = try? JSONEncoder().encode(reviewRequest) {
            defaults.set(data, forKey: Self.hotelFolioDraftReviewKey)
        }

        let navigationRequest = NavigationRequest(
            destination: .hotelReviewQueue,
            ledgerID: draft.targetLedgerID,
            createdAt: Date()
        )
        if let data = try? JSONEncoder().encode(navigationRequest) {
            defaults.set(data, forKey: Self.navigationHandoffKey)
            UserDefaults.standard.set(data, forKey: Self.navigationHandoffKey)
        }
        defaults.synchronize()
    }

    private static func hotelReviewURL(draftID: UUID) -> URL? {
        URL(string: "autoledger://hotel-stays/review?draftID=\(draftID.uuidString)")
    }

    private func writeDebug(
        stage: ImportDebugStage,
        source: ReceiptSource,
        rawText: String,
        receipt: ImportedReceipt? = nil,
        summary: String,
        transactionID: UUID? = nil
    ) {
        let record = ImportDebugRecord(
            stage: stage,
            source: source,
            imageSource: .shareExtension,
            rawText: rawText,
            parsedReceipt: receipt,
            summary: summary,
            transactionID: transactionID
        )
        guard let store = try? SQLiteTransactionStore() else { return }
        try? store.saveDebugEvent(record)
    }

    /// 将最近一次分享导入的 OCR 文本 & 解析结果写入 App Group，供主 App 回前台时读取
    private func writeShareResult(ocrText: String, receipt: ImportedReceipt) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else { return }
        defaults.set(ocrText, forKey: "share_lastOCRText")
        let receiptDict: [String: Any] = [
            "merchant": receipt.merchant,
            "amount": receipt.amount,
            "occurredAt": receipt.occurredAt.timeIntervalSince1970,
            "source": receipt.source.rawValue,
            "rawText": receipt.rawText,
            "summary": receipt.summary,
            "confidence": receipt.confidence,
            "category": receipt.suggestedCategory.rawValue,
        ]
        defaults.set(receiptDict, forKey: "share_lastReceipt")
    }

    private func markLedgerSaveNeedsCloudPush() {
        UserDefaults.standard.set(true, forKey: Self.pendingLedgerCloudPushKey)
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else { return }
        defaults.set(true, forKey: Self.pendingLedgerCloudPushKey)
        defaults.synchronize()
    }

    private func finish(message: String, openAppURL: URL? = nil, showsSuccessIcon: Bool = false) {
        activityIndicator.stopAnimating()
        statusIconView.isHidden = !showsSuccessIcon
        statusLabel.text = message

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            if let openAppURL {
                self.openContainingApp(openAppURL) { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                }
            } else {
                self.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    private func openContainingApp(_ url: URL, completion: @escaping () -> Void) {
        guard let extensionContext else {
            _ = openURLViaResponderChain(url)
            completion()
            return
        }

        extensionContext.open(url) { [weak self] didOpen in
            if !didOpen {
                _ = self?.openURLViaResponderChain(url)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                completion()
            }
        }
    }

    @discardableResult
    private func openURLViaResponderChain(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let currentResponder = responder {
            if currentResponder.responds(to: selector) {
                currentResponder.perform(selector, with: url)
                return true
            }
            responder = currentResponder.next
        }
        return false
    }
}
