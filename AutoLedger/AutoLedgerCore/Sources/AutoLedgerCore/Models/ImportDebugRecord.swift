import Foundation

public enum ImportDebugStage: String, CaseIterable, Identifiable, Sendable {
    case ocrFailed
    case parseFailed
    case duplicateSkipped
    case persisted
    case persistenceFailed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ocrFailed:         return "OCR 失败"
        case .parseFailed:       return "解析失败"
        case .duplicateSkipped:  return "重复跳过"
        case .persisted:         return "已入账"
        case .persistenceFailed: return "落盘失败"
        }
    }
}

/// 图片获取来源
public enum ImageSource: String, CaseIterable, Identifiable, Sendable {
    case photoLibrary      // 相册选取
    case camera            // 相机拍照
    case shareExtension    // 分享导入
    case shortcutIntent    // 快捷指令
    case clipboard         // 剪切板粘贴
    case unknown           // 未知 / 兼容旧数据

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .photoLibrary:   return "相册选取"
        case .camera:         return "相机拍照"
        case .shareExtension: return "分享导入"
        case .shortcutIntent: return "快捷指令"
        case .clipboard:      return "剪切板粘贴"
        case .unknown:        return "未知"
        }
    }
}

public struct ImportDebugRecord: Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let stage: ImportDebugStage
    public let source: ReceiptSource
    public let imageSource: ImageSource
    public let rawText: String
    public let parsedMerchant: String?
    public let parsedAmount: Double?
    public let summary: String
    public let llmPrompt: String?
    public let llmResponse: String?
    public var parsedReceipt: ImportedReceipt? = nil
    /// 对应入账的交易 ID（仅 stage == .persisted 时有值），用于导出时查询用户修改后的账单数据
    public let transactionID: UUID?

    /// 是否经过 LLM 解析
    public var usedLLM: Bool { llmPrompt != nil }

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        stage: ImportDebugStage,
        source: ReceiptSource,
        imageSource: ImageSource = .unknown,
        rawText: String,
        parsedReceipt: ImportedReceipt? = nil,
        summary: String,
        llmPrompt: String? = nil,
        llmResponse: String? = nil,
        transactionID: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.stage = stage
        self.source = source
        self.imageSource = imageSource
        self.rawText = rawText
        self.parsedMerchant = parsedReceipt?.merchant
        self.parsedAmount = parsedReceipt?.amount
        self.parsedReceipt = parsedReceipt
        self.summary = summary
        self.llmPrompt = llmPrompt
        self.llmResponse = llmResponse
        self.transactionID = transactionID
    }
}
