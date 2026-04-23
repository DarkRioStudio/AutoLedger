import AutoLedgerCore
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()

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
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = "正在识别…"

        view.addSubview(activityIndicator)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        activityIndicator.startAnimating()

        processSharedImage()
    }

    private func processSharedImage() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) })
        else {
            finish(message: "未找到图片")
            return
        }

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
                DispatchQueue.main.async { self.finish(message: "读取图片失败") }
                return
            }

            // OCR
            let ocrService = OCRService()
            let text: String
            do {
                text = try ocrService.recognizeText(from: imageData)
            } catch {
                DispatchQueue.main.async { self.finish(message: "OCR 失败：\(error.localizedDescription)") }
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

            // 多账单检测
            let parser = ReceiptParser()
            let multiReceipt = parser.detectMultipleReceipts(text: text)

            // 解析
            guard let receipt = parser.parse(text: text, source: source) else {
                self.writeDebug(stage: .parseFailed, source: source, rawText: text, summary: "Share Extension 解析失败")
                DispatchQueue.main.async { self.finish(message: "识别失败，请打开 App 手动导入") }
                return
            }

            // 去重 + 入账
            guard let store = try? SQLiteTransactionStore() else {
                DispatchQueue.main.async { self.finish(message: "数据库打开失败") }
                return
            }

            let existing = (try? store.loadTransactions()) ?? []
            let isDuplicate = existing.contains {
                $0.merchant == receipt.merchant &&
                abs($0.amount - receipt.amount) < 0.01 &&
                abs($0.occurredAt.timeIntervalSince(receipt.occurredAt)) < 60
            }

            // OCR 文本 Jaccard 相似度去重
            let isOCRDuplicate: Bool = {
                guard !text.isEmpty else { return false }
                let recentTexts = ((try? store.loadDebugEvents()) ?? [])
                    .filter { $0.stage == .persisted }
                    .prefix(30)
                    .map(\.rawText)
                return recentTexts.contains { !$0.isEmpty && TextSimilarity.jaccard(text, $0) > 0.8 }
            }()

            if isDuplicate || isOCRDuplicate {
                let msg = "\(receipt.merchant) ¥\(String(format: "%.2f", receipt.amount)) 已存在"
                self.writeDebug(stage: .duplicateSkipped, source: source, rawText: text, receipt: receipt, summary: msg)
                DispatchQueue.main.async { self.finish(message: msg) }
                return
            }

            let transaction = Transaction(
                merchant: receipt.merchant,
                amount: receipt.amount,
                occurredAt: receipt.occurredAt,
                category: receipt.suggestedCategory,
                source: receipt.source,
                note: "分享导入"
            )

            do {
                try store.save(transaction: transaction)
                self.writeShareResult(ocrText: text, receipt: receipt)
                var msg = "已记好：\(receipt.merchant) ¥\(String(format: "%.2f", receipt.amount))"
                if multiReceipt {
                    msg += "\n⚠️ 图片中可能有多笔账单，仅识别了一笔，建议单独截图后分别导入"
                }
                self.writeDebug(stage: .persisted, source: source, rawText: text, receipt: receipt, summary: msg)
                DispatchQueue.main.async { self.finish(message: msg) }
            } catch {
                self.writeDebug(stage: .persistenceFailed, source: source, rawText: text, receipt: receipt, summary: "入账失败：\(error.localizedDescription)")
                DispatchQueue.main.async { self.finish(message: "入账失败，请打开 App 确认") }
            }
        }
    }

    private func writeDebug(
        stage: ImportDebugStage,
        source: ReceiptSource,
        rawText: String,
        receipt: ImportedReceipt? = nil,
        summary: String
    ) {
        let record = ImportDebugRecord(
            stage: stage,
            source: source,
            imageSource: .shareExtension,
            rawText: rawText,
            parsedReceipt: receipt,
            summary: summary
        )
        guard let store = try? SQLiteTransactionStore() else { return }
        try? store.saveDebugEvent(record)
    }

    /// 将最近一次分享导入的 OCR 文本 & 解析结果写入 App Group，供主 App 回前台时读取
    private func writeShareResult(ocrText: String, receipt: ImportedReceipt) {
        guard let defaults = UserDefaults(suiteName: "group.top.darkrio326.AutoLedger") else { return }
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

    private func finish(message: String) {
        activityIndicator.stopAnimating()
        statusLabel.text = message

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
