import Foundation

public enum AutoLedgerAnalyticsPayloadValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    public var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }
        return value
    }
}

public enum AutoLedgerAnalyticsEventName: String, CaseIterable, Sendable {
    case appLaunchPerformance = "al_perf_app_launch"
    case featureSurfaceOpened = "al_feature_surface_opened"
    case importFlowStarted = "al_import_flow_started"
    case importFlowCompleted = "al_import_flow_completed"
    case confirmationState = "al_confirmation_state"
    case currencyLookupStatus = "al_currency_lookup_status"
    case hotelPDFFlowStatus = "al_hotel_pdf_flow_status"
    case commonAPIRequestStatus = "al_common_api_request_status"
    case proGateViewed = "al_pro_gate_viewed"
    case purchaseFlowStatus = "al_purchase_flow_status"
    case crashDiagnostic = "al_crash_diagnostic"
    case performanceDiagnostic = "al_performance_diagnostic"
    case privacyPayloadGuardViolation = "al_privacy_payload_guard_violation"
}

public enum AutoLedgerAnalyticsValidationError: Error, Equatable, Sendable {
    case forbiddenField(String)
    case unsupportedField(String, String)
}

public struct AutoLedgerAnalyticsEvent: Equatable, Sendable {
    public let name: AutoLedgerAnalyticsEventName
    public let payload: [String: AutoLedgerAnalyticsPayloadValue]

    public var eventName: String { name.rawValue }

    private init(
        name: AutoLedgerAnalyticsEventName,
        payload: [String: AutoLedgerAnalyticsPayloadValue]
    ) {
        self.name = name
        self.payload = payload
    }

    public static func make(
        _ name: AutoLedgerAnalyticsEventName,
        payload: [String: AutoLedgerAnalyticsPayloadValue]
    ) throws -> AutoLedgerAnalyticsEvent {
        let allowedFields = AutoLedgerAnalyticsCatalog.allowedFields(for: name)
        for key in payload.keys {
            if AutoLedgerAnalyticsCatalog.isForbiddenField(key) {
                throw AutoLedgerAnalyticsValidationError.forbiddenField(key)
            }
            if !allowedFields.contains(key) {
                throw AutoLedgerAnalyticsValidationError.unsupportedField(key, name.rawValue)
            }
        }
        return AutoLedgerAnalyticsEvent(name: name, payload: payload)
    }
}

public enum AutoLedgerAnalyticsUploadError: Error, Equatable, Sendable {
    case invalidResponse
    case httpFailure(statusCode: Int)
}

public struct AutoLedgerAnalyticsUploadClient: Sendable {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public let endpointURL: URL
    private let transport: Transport

    public init(
        endpointURL: URL = URL(string: "https://api.darkrio326.top/v1/analytics/events")!,
        transport: @escaping Transport = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.endpointURL = endpointURL
        self.transport = transport
    }

    public func upload(
        events: [AutoLedgerAnalyticsEvent],
        appVersion: String,
        buildNumber: String,
        osMajor: String,
        deviceClass: String
    ) async throws {
        guard !events.isEmpty else { return }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(
            events: events,
            appVersion: appVersion,
            buildNumber: buildNumber,
            osMajor: osMajor,
            deviceClass: deviceClass
        ))

        let (_, response) = try await transport(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AutoLedgerAnalyticsUploadError.invalidResponse
        }
        guard 200...299 ~= httpResponse.statusCode else {
            throw AutoLedgerAnalyticsUploadError.httpFailure(statusCode: httpResponse.statusCode)
        }
    }

    private func requestBody(
        events: [AutoLedgerAnalyticsEvent],
        appVersion: String,
        buildNumber: String,
        osMajor: String,
        deviceClass: String
    ) -> [String: Any] {
        [
            "schemaVersion": 1,
            "app": "autoledger",
            "events": events.map { event in
                [
                    "eventName": event.eventName,
                    "appVersion": appVersion,
                    "buildNumber": buildNumber,
                    "osMajor": osMajor,
                    "deviceClass": deviceClass,
                    "payload": event.payload.mapValues(\.jsonValue)
                ]
            }
        ]
    }
}

public struct AutoLedgerAnalyticsEventDefinition: Equatable, Sendable {
    public let eventName: String
    public let purpose: String
    public let payloadFields: [String]
    public let forbiddenFields: [String]
    public let privacyLabelImpact: String
    public let dashboardUsage: String

    public init(
        eventName: String,
        purpose: String,
        payloadFields: [String],
        forbiddenFields: [String],
        privacyLabelImpact: String,
        dashboardUsage: String
    ) {
        self.eventName = eventName
        self.purpose = purpose
        self.payloadFields = payloadFields
        self.forbiddenFields = forbiddenFields
        self.privacyLabelImpact = privacyLabelImpact
        self.dashboardUsage = dashboardUsage
    }
}

public struct AutoLedgerAnalyticsDashboardMetric: Equatable, Sendable {
    public let metricID: String
    public let definition: String
    public let eventNames: [String]
    public let marketingGate: String

    public init(
        metricID: String,
        definition: String,
        eventNames: [String],
        marketingGate: String
    ) {
        self.metricID = metricID
        self.definition = definition
        self.eventNames = eventNames
        self.marketingGate = marketingGate
    }
}

public struct AutoLedgerAnalyticsMetricSnapshot: Equatable, Sendable {
    public let metricID: String
    public let value: Double?
    public let unit: String
    public let numerator: Int
    public let denominator: Int
    public let status: String
    public let breakdown: [String: Int]

    public init(
        metricID: String,
        value: Double?,
        unit: String,
        numerator: Int,
        denominator: Int,
        status: String,
        breakdown: [String: Int] = [:]
    ) {
        self.metricID = metricID
        self.value = value
        self.unit = unit
        self.numerator = numerator
        self.denominator = denominator
        self.status = status
        self.breakdown = breakdown
    }
}

public struct AutoLedgerAnalyticsDashboardSnapshot: Equatable, Sendable {
    public let metrics: [AutoLedgerAnalyticsMetricSnapshot]

    public init(metrics: [AutoLedgerAnalyticsMetricSnapshot]) {
        self.metrics = metrics
    }

    public func metric(id: String) -> AutoLedgerAnalyticsMetricSnapshot? {
        metrics.first { $0.metricID == id }
    }
}

public struct AutoLedgerAnalyticsRecorder: Sendable {
    public private(set) var recordedEvents: [AutoLedgerAnalyticsEvent]

    public init(recordedEvents: [AutoLedgerAnalyticsEvent] = []) {
        self.recordedEvents = recordedEvents
    }

    public mutating func record(
        _ name: AutoLedgerAnalyticsEventName,
        payload: [String: AutoLedgerAnalyticsPayloadValue]
    ) throws {
        do {
            recordedEvents.append(try AutoLedgerAnalyticsEvent.make(name, payload: payload))
        } catch let error as AutoLedgerAnalyticsValidationError {
            recordPrivacyGuardViolation(checkedName: name, payload: payload, error: error)
            throw error
        }
    }

    public mutating func record(_ event: AutoLedgerAnalyticsEvent) {
        recordedEvents.append(event)
    }

    public func makeMinimalDashboardSnapshot() -> AutoLedgerAnalyticsDashboardSnapshot {
        let launchEvents = events(named: .appLaunchPerformance)
        let launchCompletionEvents = launchEvents.filter {
            $0.stringPayload("launch_type") == "foreground" && $0.stringPayload("result") == "success"
        }
        let importStarts = events(named: .importFlowStarted).count
        let importSuccesses = events(named: .importFlowCompleted).filter { $0.stringPayload("status") == "success" }.count
        let importCompletions = events(named: .importFlowCompleted)
        let confirmationEvents = events(named: .confirmationState)
        let confirmationDiscards = confirmationEvents.filter { $0.stringPayload("confirm_status") == "discarded" }.count
        let currencyEvents = events(named: .currencyLookupStatus)
        let currencySuccesses = currencyEvents.filter { $0.stringPayload("rate_lookup_status") == "success" }.count
        let hotelPDFEvents = events(named: .hotelPDFFlowStatus)
        let hotelPDFSuccesses = hotelPDFEvents.filter { $0.stringPayload("status") == "success" }.count
        let commonAPIEvents = events(named: .commonAPIRequestStatus)
        let purchaseEvents = events(named: .purchaseFlowStatus)
        let purchaseFailures = purchaseEvents.filter { event in
            switch event.stringPayload("storekit_status") {
            case "failed", "cancelled", "canceled", "unknown":
                return true
            default:
                return false
            }
        }.count
        let crashEvents = events(named: .crashDiagnostic)
        let uncleanSessionRecoveryEvents = crashEvents.filter {
            $0.stringPayload("diagnostic_type") == "unclean_active_session" &&
            $0.stringPayload("signal_source") == "session_marker"
        }
        let systemCrashEvents = crashEvents.filter {
            !($0.stringPayload("diagnostic_type") == "unclean_active_session" &&
              $0.stringPayload("signal_source") == "session_marker")
        }
        let performanceEvents = events(named: .performanceDiagnostic)
        let slowPerformanceEvents = performanceEvents.filter { event in
            switch event.stringPayload("duration_ms_bucket") {
            case "3s_10s", "10s_30s", "over_30s":
                return true
            default:
                return event.stringPayload("severity") == "warning" || event.stringPayload("severity") == "critical"
            }
        }
        let privacyViolations = events(named: .privacyPayloadGuardViolation).count

        return AutoLedgerAnalyticsDashboardSnapshot(metrics: [
            countMetric(
                "feature_surface_open_count",
                value: events(named: .featureSurfaceOpened).count,
                breakdown: breakdown(events(named: .featureSurfaceOpened), field: "surface")
            ),
            countMetric("launch_completion_count", value: launchCompletionEvents.count),
            countMetric("unclean_session_recovery_count", value: uncleanSessionRecoveryEvents.count),
            percentMetric(
                "import_completion_rate",
                numerator: importSuccesses,
                denominator: importStarts
            ),
            countMetric(
                "import_error_code_top_n",
                value: importCompletions.count,
                breakdown: breakdown(importCompletions, field: "error_code")
            ),
            percentMetric(
                "confirmation_discard_rate",
                numerator: confirmationDiscards,
                denominator: confirmationEvents.count
            ),
            percentMetric(
                "currency_lookup_success_rate",
                numerator: currencySuccesses,
                denominator: currencyEvents.count
            ),
            percentMetric(
                "hotel_pdf_completion_rate",
                numerator: hotelPDFSuccesses,
                denominator: hotelPDFEvents.count
            ),
            countMetric(
                "common_api_status_top_n",
                value: commonAPIEvents.count,
                breakdown: breakdown(commonAPIEvents, field: "http_status_bucket")
            ),
            countMetric(
                "pro_gate_boundary_risk",
                value: events(named: .proGateViewed).count,
                breakdown: breakdown(events(named: .proGateViewed), field: "dismiss_reason_code")
            ),
            percentMetric(
                "purchase_flow_failure_rate",
                numerator: purchaseFailures,
                denominator: purchaseEvents.count
            ),
            countMetric(
                "crash_diagnostic_count",
                value: systemCrashEvents.count,
                breakdown: breakdown(systemCrashEvents, field: "diagnostic_type")
            ),
            countMetric(
                "slow_operation_count",
                value: slowPerformanceEvents.count,
                breakdown: breakdown(slowPerformanceEvents, field: "operation")
            ),
            countMetric(
                "performance_operation_top_n",
                value: performanceEvents.count,
                breakdown: breakdown(performanceEvents, field: "operation")
            ),
            countMetric(
                "privacy_payload_violation_count",
                value: privacyViolations
            )
        ])
    }

    private func events(named name: AutoLedgerAnalyticsEventName) -> [AutoLedgerAnalyticsEvent] {
        recordedEvents.filter { $0.name == name }
    }

    private mutating func recordPrivacyGuardViolation(
        checkedName: AutoLedgerAnalyticsEventName,
        payload: [String: AutoLedgerAnalyticsPayloadValue],
        error: AutoLedgerAnalyticsValidationError
    ) {
        let violationType: String
        let blockedFieldCategory: String
        switch error {
        case let .forbiddenField(field):
            violationType = "forbidden_field"
            blockedFieldCategory = Self.blockedFieldCategory(for: field)
        case .unsupportedField:
            violationType = "unsupported_field"
            blockedFieldCategory = "unsupported"
        }

        let violationPayload: [String: AutoLedgerAnalyticsPayloadValue] = [
            "event_id": .string(payload["event_id"]?.stringValue ?? UUID().uuidString),
            "app_version": .string(payload["app_version"]?.stringValue ?? "unknown"),
            "event_name_checked": .string(checkedName.rawValue),
            "violation_type": .string(violationType),
            "blocked_field_category": .string(blockedFieldCategory),
            "build_number": .string(payload["build_number"]?.stringValue ?? "unknown")
        ]
        if let violation = try? AutoLedgerAnalyticsEvent.make(.privacyPayloadGuardViolation, payload: violationPayload) {
            recordedEvents.append(violation)
        }
    }

    private func percentMetric(
        _ metricID: String,
        numerator: Int,
        denominator: Int
    ) -> AutoLedgerAnalyticsMetricSnapshot {
        AutoLedgerAnalyticsMetricSnapshot(
            metricID: metricID,
            value: denominator > 0 ? Double(numerator) / Double(denominator) * 100 : nil,
            unit: "percent",
            numerator: numerator,
            denominator: denominator,
            status: denominator > 0 ? "available" : "insufficient_data"
        )
    }

    private func countMetric(
        _ metricID: String,
        value: Int,
        breakdown: [String: Int] = [:]
    ) -> AutoLedgerAnalyticsMetricSnapshot {
        AutoLedgerAnalyticsMetricSnapshot(
            metricID: metricID,
            value: Double(value),
            unit: "count",
            numerator: value,
            denominator: 1,
            status: "available",
            breakdown: breakdown
        )
    }

    private func breakdown(
        _ events: [AutoLedgerAnalyticsEvent],
        field: String
    ) -> [String: Int] {
        events.reduce(into: [:]) { result, event in
            let key = event.stringPayload(field) ?? "unknown"
            result[key, default: 0] += 1
        }
    }

    private static func blockedFieldCategory(for field: String) -> String {
        let normalized = field
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        if normalized.contains("amount") || normalized.contains("merchant") {
            return "financial"
        }
        if normalized.contains("pdf") || normalized.contains("screenshot") || normalized.contains("photo") || normalized.contains("ocr") {
            return "document"
        }
        if normalized.contains("email") || normalized.contains("hotel") || normalized.contains("room") {
            return "travel_identity"
        }
        if normalized.contains("latitude") || normalized.contains("longitude") || normalized.contains("geo") || normalized.contains("location") {
            return "location"
        }
        if normalized.contains("transaction") || normalized.contains("receipt") || normalized.contains("payment") {
            return "purchase_identifier"
        }
        return "unknown"
    }
}

private extension AutoLedgerAnalyticsEvent {
    func stringPayload(_ key: String) -> String? {
        payload[key]?.stringValue
    }
}

private extension AutoLedgerAnalyticsPayloadValue {
    var jsonValue: Any {
        switch self {
        case let .string(value):
            return value
        case let .int(value):
            return value
        case let .double(value):
            return value
        case let .bool(value):
            return value
        }
    }
}

public enum AutoLedgerAnalyticsCatalog {
    public static let globallyForbiddenFields = [
        "账单金额",
        "商户",
        "截图",
        "照片",
        "PDF",
        "邮箱",
        "酒店名",
        "房号",
        "精确位置",
        "交易号",
        "票据原文",
        "消费明细",
        "StoreKit transaction id",
        "receipt"
    ]

    public static let eventDefinitions: [AutoLedgerAnalyticsEventDefinition] = [
        definition(
            .appLaunchPerformance,
            purpose: "观察 1.6.0 推广前启动性能是否影响首次体验。",
            fields: ["event_id", "app_version", "build_number", "os_major", "device_class", "launch_type", "duration_ms_bucket", "result", "error_code"],
            privacy: "Diagnostics / Performance Data；not linked；not tracking。",
            dashboard: "启动完成信号与启动耗时 bucket；前次会话恢复只进入诊断信号，不作为启动失败。"
        ),
        definition(
            .featureSurfaceOpened,
            purpose: "观察用户主要打开哪些 App 功能入口，辅助判断导航、功能命名和年度产品复盘。",
            fields: ["event_id", "app_version", "surface", "entry_surface", "is_pro_surface", "open_reason"],
            privacy: "Usage Data / Product Interaction；not linked；not tracking。",
            dashboard: "Tab / 页面入口分布、Pro 自动化入口热度、容易被忽略的功能面。"
        ),
        definition(
            .importFlowStarted,
            purpose: "观察导入入口使用分布，判断 marketing 是否过度强调某个路径。",
            fields: ["event_id", "app_version", "flow_type", "input_type", "entry_surface", "is_pro_surface", "start_status"],
            privacy: "Usage Data / Product Interaction；not linked；not tracking。",
            dashboard: "各入口启动量、Free / Pro 入口占比、导入路径关注度。"
        ),
        definition(
            .importFlowCompleted,
            purpose: "观察导入流程完成率和失败类型，支撑发布前稳定性判断。",
            fields: ["event_id", "app_version", "flow_type", "input_type", "status", "duration_ms_bucket", "retry_count_bucket", "error_code"],
            privacy: "Usage Data + Diagnostics；not linked；not tracking。",
            dashboard: "导入完成率、失败率、超时 bucket、错误码 Top N。"
        ),
        definition(
            .confirmationState,
            purpose: "观察确认页是否让用户理解保存前由用户复核。",
            fields: ["event_id", "app_version", "flow_type", "required_field_count_bucket", "edited_field_count_bucket", "confirm_status", "discard_reason_code"],
            privacy: "Usage Data / Product Interaction；not linked；not tracking。",
            dashboard: "确认页放弃率、编辑 bucket、误解自动入账的反馈对照。"
        ),
        definition(
            .currencyLookupStatus,
            purpose: "观察跨币种确认的基础设施状态，不采集交易金额。",
            fields: ["event_id", "app_version", "lookup_context", "has_foreign_currency", "rate_lookup_status", "latency_ms_bucket", "error_code", "cache_status"],
            privacy: "Diagnostics / Other Diagnostic Data；not linked；not tracking。",
            dashboard: "汇率查询成功率、延迟 bucket、失败码、是否需要暂缓跨币种主文案。"
        ),
        definition(
            .hotelPDFFlowStatus,
            purpose: "观察手动酒店水单 PDF 路径是否稳定，同时避免收集酒店信息。",
            fields: ["event_id", "app_version", "flow_type", "page_count_bucket", "status", "duration_ms_bucket", "error_code"],
            privacy: "Usage Data + Diagnostics；not linked；not tracking。",
            dashboard: "酒店 PDF 完成率、失败码、是否影响旅行账单文案节奏。"
        ),
        definition(
            .commonAPIRequestStatus,
            purpose: "观察 Common API 地点 / 货币基础设施可用性，不记录请求内容。",
            fields: ["event_id", "app_version", "endpoint_group", "http_status_bucket", "latency_ms_bucket", "error_code", "cache_status"],
            privacy: "Diagnostics / Other Diagnostic Data；not linked；not tracking。",
            dashboard: "基础设施错误率、p95 延迟、发布前 hold 条件。"
        ),
        definition(
            .proGateViewed,
            purpose: "观察 Pro 效率层是否被理解为省时间，而不是锁数据。",
            fields: ["event_id", "app_version", "surface", "pro_feature_area", "copy_variant", "user_action", "dismiss_reason_code"],
            privacy: "Usage Data / Product Interaction；not linked；not tracking。",
            dashboard: "Pro 边界文案点击 / 关闭、是否触发 Pro 锁数据反馈。"
        ),
        definition(
            .purchaseFlowStatus,
            purpose: "观察 StoreKit 购买路径状态，只记录流程状态和错误码。",
            fields: ["event_id", "app_version", "product_tier", "storekit_step", "storekit_status", "error_code", "duration_ms_bucket"],
            privacy: "Usage Data + Diagnostics；not linked；not tracking。",
            dashboard: "购买流程失败率、StoreKit 错误码、是否需要调整 Review Notes 或 Pro 文案。"
        ),
        definition(
            .crashDiagnostic,
            purpose: "观察真机崩溃、hang 和异常退出信号是否影响可用性，不上传堆栈或用户内容。",
            fields: ["event_id", "app_version", "diagnostic_type", "signal_source", "severity", "count_bucket", "termination_state", "error_code"],
            privacy: "Diagnostics / Crash Data；not linked；not tracking。",
            dashboard: "崩溃 / 异常退出计数、MetricKit crash / hang 分布和发布阻断判断。"
        ),
        definition(
            .performanceDiagnostic,
            purpose: "观察真机卡顿和关键操作耗时 bucket，定位 Tab 切换、月报和数据清洗等高频卡点。",
            fields: ["event_id", "app_version", "diagnostic_type", "surface", "operation", "duration_ms_bucket", "count_bucket", "severity", "result", "error_code"],
            privacy: "Diagnostics / Performance Data；not linked；not tracking。",
            dashboard: "慢操作次数、操作耗时 bucket、MetricKit hang / CPU / disk write 诊断分布。"
        ),
        definition(
            .privacyPayloadGuardViolation,
            purpose: "在测试和预发布中发现埋点 payload 越界，阻止 marketing 放大。",
            fields: ["event_id", "app_version", "event_name_checked", "violation_type", "blocked_field_category", "build_number"],
            privacy: "Diagnostics / Other Diagnostic Data；not linked；not tracking。",
            dashboard: "隐私 QA 阻塞数；任何非零值都进入发布前 review。"
        )
    ]

    public static let minimalDashboardMetrics: [AutoLedgerAnalyticsDashboardMetric] = [
        metric("launch_completion_count", "已到达前台启动上报的次数，不推断总启动成功率。", [.appLaunchPerformance], "用于确认启动上报覆盖，不作为发布成功率。"),
        metric("unclean_session_recovery_count", "前次 active 会话在下次启动时被恢复检测到的次数。", [.crashDiagnostic], "含系统回收和调试器停止；不等同崩溃率。"),
        metric("feature_surface_open_count", "匿名功能入口打开次数，按固定 surface 枚举聚合。", [.featureSurfaceOpened], "只用于产品体验判断，不做用户画像。"),
        metric("import_completion_rate", "导入开始到导入成功完成的比例。", [.importFlowStarted, .importFlowCompleted], "主路径异常下降需调整文案或暂缓。"),
        metric("import_error_code_top_n", "导入失败事件按错误码聚合。", [.importFlowCompleted], "新增高频错误需进入 launch blocker review。"),
        metric("confirmation_discard_rate", "确认页放弃事件占确认页状态事件比例。", [.confirmationState], "高放弃率时不要强调自动化已顺滑。"),
        metric("currency_lookup_success_rate", "跨币种查询成功占比。", [.currencyLookupStatus], "未稳定前 ASC 文案继续用发布准备。"),
        metric("hotel_pdf_completion_rate", "酒店 PDF 导入流程成功完成占比。", [.hotelPDFFlowStatus], "失败率升高时暂停放大酒店水单卖点。"),
        metric("common_api_status_top_n", "Common API 请求按 HTTP 状态 bucket 聚合。", [.commonAPIRequestStatus], "4xx / 5xx 或 network_error 异常时先修基础设施。"),
        metric("pro_gate_boundary_risk", "Pro gate 关闭原因和 Pro confusion 反馈对照。", [.proGateViewed], "出现 Pro 锁数据误解时先改文案。"),
        metric("purchase_flow_failure_rate", "StoreKit failed / canceled / unknown 状态占比。", [.purchaseFlowStatus], "错误码异常时暂停付费转化文案。"),
        metric("crash_diagnostic_count", "MetricKit crash / hang / 异常退出信号按诊断类型聚合。", [.crashDiagnostic], "任何新增崩溃信号都进入发布前 review。"),
        metric("slow_operation_count", "关键操作超过 3 秒或系统诊断标记 warning / critical 的次数。", [.performanceDiagnostic], "高频慢操作先做 Instruments 和局部优化。"),
        metric("performance_operation_top_n", "关键操作耗时事件按 operation 枚举聚合。", [.performanceDiagnostic], "用于判断用户主要卡在哪些路径。"),
        metric("privacy_payload_violation_count", "被 guard 拦截的 forbidden field 次数。", [.privacyPayloadGuardViolation], "非零即阻塞 marketing。")
    ]

    public static func allowedFields(for name: AutoLedgerAnalyticsEventName) -> Set<String> {
        guard let definition = eventDefinitions.first(where: { $0.eventName == name.rawValue }) else {
            return []
        }
        return Set(definition.payloadFields)
    }

    public static func isForbiddenField(_ key: String) -> Bool {
        let normalized = normalizedKey(key)
        return forbiddenKeyFragments.contains { normalized.contains($0) }
    }

    private static let forbiddenKeyFragments: [String] = [
        "amount",
        "merchant",
        "screenshot",
        "photo",
        "image",
        "pdf",
        "file_name",
        "filename",
        "email",
        "mail_subject",
        "mail_body",
        "hotel_name",
        "hotelname",
        "room",
        "latitude",
        "longitude",
        "geo",
        "precise_location",
        "exact_location",
        "raw_text",
        "ocr_text",
        "receipt_text",
        "receipt",
        "transaction_id",
        "transactionid",
        "apple_id",
        "app_account_token",
        "payment_method",
        "billing_address"
    ]

    private static func definition(
        _ name: AutoLedgerAnalyticsEventName,
        purpose: String,
        fields: [String],
        privacy: String,
        dashboard: String
    ) -> AutoLedgerAnalyticsEventDefinition {
        AutoLedgerAnalyticsEventDefinition(
            eventName: name.rawValue,
            purpose: purpose,
            payloadFields: fields,
            forbiddenFields: globallyForbiddenFields,
            privacyLabelImpact: privacy,
            dashboardUsage: dashboard
        )
    }

    private static func metric(
        _ metricID: String,
        _ definition: String,
        _ eventNames: [AutoLedgerAnalyticsEventName],
        _ marketingGate: String
    ) -> AutoLedgerAnalyticsDashboardMetric {
        AutoLedgerAnalyticsDashboardMetric(
            metricID: metricID,
            definition: definition,
            eventNames: eventNames.map(\.rawValue),
            marketingGate: marketingGate
        )
    }

    private static func normalizedKey(_ key: String) -> String {
        key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
}
