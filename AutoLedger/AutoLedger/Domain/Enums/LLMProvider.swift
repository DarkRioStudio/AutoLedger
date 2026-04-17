import Foundation

/// 端侧大模型提供方枚举
enum LLMProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case appleFoundation = "apple"
    case gemma           = "gemma"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleFoundation: return "Apple Intelligence"
        case .gemma:           return "Gemma-2 2B"
        }
    }

    var subtitle: String {
        switch self {
        case .appleFoundation: return "iOS 26+ 系统内置，无需下载"
        case .gemma:           return "Google 端侧模型（MediaPipe），需下载约 2.5 GB"
        }
    }

    var iconName: String {
        switch self {
        case .appleFoundation: return "apple.logo"
        case .gemma:           return "cpu.fill"
        }
    }

    /// 运行时可用性（同步检查）
    @MainActor
    var isAvailable: Bool {
        switch self {
        case .appleFoundation:
            if #available(iOS 26.0, *) {
                return _isAppleFMAvailable()
            }
            return false
        case .gemma:
            if GemmaService.isRunningInExtension { return false }
            return GemmaService.shared.isModelDownloaded
        }
    }

    /// 不可用原因（供 UI 展示）
    @MainActor
    var unavailableReason: String? {
        switch self {
        case .appleFoundation:
            if !isAvailable { return "当前设备/地区不支持 Apple Intelligence" }
        case .gemma:
            if GemmaService.isRunningInExtension { return "Extension 中不可用" }
            if !isAvailable { return "模型尚未下载，请先下载" }
        }
        return nil
    }

    // MARK: - UserDefaults 持久化

    private static let key = "selectedLLMProvider"
    private static let enhancementKey = "llmEnhancementEnabled"

    /// 模型识别增强是否启用
    static var isEnhancementEnabled: Bool {
        get {
            // 默认启用（首次安装 key 不存在时）
            if UserDefaults.standard.object(forKey: enhancementKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: enhancementKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enhancementKey)
        }
    }

    static var userSelected: LLMProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let provider = LLMProvider(rawValue: raw) else {
                return .appleFoundation
            }
            return provider
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}

// MARK: - Availability helpers

import FoundationModels

@available(iOS 26.0, *)
private func _isAppleFMAvailable() -> Bool {
    SystemLanguageModel.default.isAvailable
}
