import Foundation

public enum ImportDebugStage: String, CaseIterable, Identifiable, Sendable {
    case ocrFailed
    case parseFailed
    case duplicateSkipped
    case persisted
    case persistenceFailed
    case hotelFolioTextExtracted
    case hotelFolioLLMRequest
    case hotelFolioLLMResponse
    case hotelFolioLocalization
    case hotelFolioExchangeRate
    case hotelFolioEmailScan
    case hotelFolioParseFailed
    case hotelFolioDraftSaved
    case hotelFolioPosted

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ocrFailed:         return "OCR 失败"
        case .parseFailed:       return "解析失败"
        case .duplicateSkipped:  return "重复跳过"
        case .persisted:         return "已入账"
        case .persistenceFailed: return "落盘失败"
        case .hotelFolioTextExtracted: return "酒店水单文本"
        case .hotelFolioLLMRequest:    return "酒店 LLM 请求"
        case .hotelFolioLLMResponse:   return "酒店 LLM 输出"
        case .hotelFolioLocalization:  return "酒店本地化"
        case .hotelFolioExchangeRate:  return "酒店汇率"
        case .hotelFolioEmailScan:     return "酒店邮箱扫描"
        case .hotelFolioParseFailed:   return "酒店识别失败"
        case .hotelFolioDraftSaved:    return "酒店待确认"
        case .hotelFolioPosted:        return "酒店已入账"
        }
    }

    public var isHotelFolioStage: Bool {
        switch self {
        case .hotelFolioTextExtracted,
             .hotelFolioLLMRequest,
             .hotelFolioLLMResponse,
             .hotelFolioLocalization,
             .hotelFolioExchangeRate,
             .hotelFolioEmailScan,
             .hotelFolioParseFailed,
             .hotelFolioDraftSaved,
             .hotelFolioPosted:
            return true
        case .ocrFailed, .parseFailed, .duplicateSkipped, .persisted, .persistenceFailed:
            return false
        }
    }
}

/// 图片获取来源
public enum ImageSource: String, CaseIterable, Identifiable, Sendable {
    case photoLibrary      // 相册选取
    case camera            // 相机拍照
    case shareExtension    // 分享导入
    case shortcutIntent    // 快捷指令
    case voiceIntent       // 语音快捷指令 / 语音输入
    case clipboard         // 剪切板粘贴
    case documentPDF       // 本地 PDF 文档
    case emailAttachment   // 本地邮箱附件
    case cloudWorker       // 云端 Worker 推送
    case unknown           // 未知 / 兼容旧数据

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .photoLibrary:   return "相册选取"
        case .camera:         return "相机拍照"
        case .shareExtension: return "分享导入"
        case .shortcutIntent: return "快捷指令"
        case .voiceIntent:    return "语音记账"
        case .clipboard:      return "剪切板粘贴"
        case .documentPDF:    return "本地 PDF"
        case .emailAttachment:return "邮箱附件"
        case .cloudWorker:    return "云端 Worker"
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
    /// 使用的 LLM 模型标识（apple / gemma）
    public let llmProvider: String?
    /// LLM 推理耗时（毫秒）
    public let llmLatencyMs: Int?
    /// LLM 返回的置信度
    public let llmConfidence: Double?
    /// 是否走了规则兜底
    public let usedRuleFallback: Bool

    /// 是否经过 LLM 解析
    public var usedLLM: Bool {
        switch stage {
        case .hotelFolioLLMRequest, .hotelFolioLLMResponse, .hotelFolioLocalization:
            return true
        case .hotelFolioParseFailed:
            return llmProvider?.hasPrefix("external_") == true || llmResponse != nil
        case .hotelFolioExchangeRate:
            return false
        default:
            return llmPrompt != nil
        }
    }

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
        transactionID: UUID? = nil,
        llmProvider: String? = nil,
        llmLatencyMs: Int? = nil,
        llmConfidence: Double? = nil,
        usedRuleFallback: Bool = true
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
        self.llmProvider = llmProvider
        self.llmLatencyMs = llmLatencyMs
        self.llmConfidence = llmConfidence
        self.usedRuleFallback = usedRuleFallback
    }
}
