import Foundation
import OSLog
import CryptoKit
@preconcurrency import MediaPipeTasksGenAI
import MediaPipeTasksGenAIC

private let logger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "GemmaService")

/// Gemma-2 2B 端侧模型管理：manifest 版本检查 → 下载 → SHA-256 校验 → 加载 → 推理 → 删除
/// 基于 MediaPipe LLM Inference API；后期 LiteRT-LM Swift SDK 就绪后升级。
@MainActor @Observable
final class GemmaService {
    static let shared = GemmaService()

    // MARK: - State

    enum ModelState: Sendable {
        case notDownloaded
        case checkingManifest
        case downloading(progress: Double)
        case verifying
        case ready
        case updateAvailable(remote: String, local: String)
        case error(String)
    }

    private(set) var state: ModelState = .notDownloaded
    private var llmInference: LlmInference?
    private var isLoading = false

    /// 推理结束后延迟卸载模型的计时器（默认 120 秒无新调用则释放内存）
    private var unloadTask: Task<Void, Never>?
    private static let autoUnloadDelay: UInt64 = 120 * 1_000_000_000 // 2 分钟

    // MARK: - 模型加载耗时埋点

    private static let loadTimeSamplesKey = "gemmaLoadTimeSamples"
    private static let inferenceTimeSamplesKey = "gemmaInferenceTimeSamples"
    private static let maxSamples = 30

    /// 最近一次成功加载模型的耗时（秒）
    private(set) var lastLoadTimeSeconds: Double? = nil
    /// 最近一次推理耗时（秒）
    private(set) var lastInferenceTimeSeconds: Double? = nil
    /// 累计成功加载次数
    private(set) var loadCount: Int = 0
    /// 累计推理次数
    private(set) var inferenceCount: Int = 0

    // MARK: - P50 / P90 统计

    /// 加载耗时 P50 / P90（秒）
    var loadTimeP50: Double? { Self.percentile(Self.loadSamples, 0.50) }
    var loadTimeP90: Double? { Self.percentile(Self.loadSamples, 0.90) }
    /// 推理耗时 P50 / P90（秒）
    var inferenceTimeP50: Double? { Self.percentile(Self.inferenceSamples, 0.50) }
    var inferenceTimeP90: Double? { Self.percentile(Self.inferenceSamples, 0.90) }

    private static var loadSamples: [Double] {
        (UserDefaults.standard.array(forKey: loadTimeSamplesKey) as? [Double]) ?? []
    }
    private static var inferenceSamples: [Double] {
        (UserDefaults.standard.array(forKey: inferenceTimeSamplesKey) as? [Double]) ?? []
    }

    /// 计算分位数（线性插值）
    private static func percentile(_ samples: [Double], _ p: Double) -> Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let index = p * Double(sorted.count - 1)
        let lower = Int(index)
        let upper = min(lower + 1, sorted.count - 1)
        let fraction = index - Double(lower)
        return sorted[lower] + fraction * (sorted[upper] - sorted[lower])
    }

    // MARK: - CDN 配置

    private static let manifestURL = "https://cdn.darkrio326.top/gemma/2b-it/v1/manifest.json"

    /// 预留认证头；目前 R2 是公开桶，无需 token。
    /// 后续如开启 Cloudflare Access / 签名 URL，在此添加 Bearer 或 query token。
    private static var authHeaders: [String: String] { [:] }

    // MARK: - 本地路径

    private var modelDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GemmaModels", isDirectory: true)
    }

    private var modelFilePath: URL {
        modelDirectory.appendingPathComponent("model.bin")
    }

    private var localManifestPath: URL {
        modelDirectory.appendingPathComponent("manifest.json")
    }

    /// 模型实际路径：优先 Application Support（下载），其次 Bundle（内置）
    private var resolvedModelPath: String? {
        let downloaded = modelFilePath.path
        if FileManager.default.fileExists(atPath: downloaded) { return downloaded }
        return Bundle.main.path(forResource: "model", ofType: "bin")
    }

    var isModelReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// 模型文件已下载到本地（可能尚未加载到内存）
    var isModelDownloaded: Bool {
        resolvedModelPath != nil
    }

    /// 当前是否运行在 App Extension 中（Extension 内存上限 ~50 MB，无法加载 2.5 GB 模型）
    static let isRunningInExtension: Bool = {
        Bundle.main.bundlePath.hasSuffix(".appex")
    }()

    /// 模型文件大小（MB），用于 UI 展示
    var modelSizeMB: Int? {
        guard let path = resolvedModelPath,
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return nil }
        return Int(size / 1_048_576)
    }

    /// 当前已安装版本号（来自本地 manifest）
    var installedVersion: String? {
        guard let data = try? Data(contentsOf: localManifestPath),
              let manifest = try? JSONDecoder().decode(ModelManifest.self, from: data) else { return nil }
        return manifest.version
    }

    private init() {
        // 不在 init 同步加载 2.5 GB 模型，改为首次使用时异步懒加载
        // state 保持 .notDownloaded（文件存在但模型未加载到内存）
        let loadSamples = (UserDefaults.standard.array(forKey: Self.loadTimeSamplesKey) as? [Double]) ?? []
        loadCount = loadSamples.count
        lastLoadTimeSeconds = loadSamples.last
        let infSamples = (UserDefaults.standard.array(forKey: Self.inferenceTimeSamplesKey) as? [Double]) ?? []
        inferenceCount = infSamples.count
        lastInferenceTimeSeconds = infSamples.last
    }

    /// 异步懒加载：首次调用时加载模型，后续直接返回。
    /// 供 generate() 和 UI 自动调用。
    func ensureLoaded() async {
        if Self.isRunningInExtension { return }  // Extension 内存不足，跳过
        if isModelReady || isLoading { return }
        guard resolvedModelPath != nil else { return }
        isLoading = true
        defer { isLoading = false }
        unloadTask?.cancel()  // 取消即将卸载的计时器
        unloadTask = nil
        await loadModelAsync()
    }

    /// 释放模型内存（保留文件），下次 ensureLoaded() 会重新加载
    func unloadModel() {
        unloadTask?.cancel()
        unloadTask = nil
        llmInference = nil
        if resolvedModelPath != nil {
            state = .notDownloaded  // 文件还在，仅释放内存
        }
        logger.info("[Gemma] 模型已从内存卸载")
    }

    /// 推理结束后调度延迟卸载；如果期间有新的 ensureLoaded/generate 调用，计时器会被取消
    private func scheduleAutoUnload() {
        unloadTask?.cancel()
        unloadTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.autoUnloadDelay)
                await self?.unloadModel()
            } catch { /* cancelled */ }
        }
    }

    // MARK: - Manifest 检查

    /// 检查远端 manifest，对比本地版本。返回远端 manifest（供后续下载使用）。
    func checkForUpdate() async {
        state = .checkingManifest
        do {
            let remote = try await fetchManifest()
            if let local = loadLocalManifest(),
               local.version == remote.version,
               local.sha256 == remote.sha256,
               FileManager.default.fileExists(atPath: modelFilePath.path) {
                // 版本 + 哈希一致且文件存在 → 已是最新
                loadModel()
                return
            }
            if let local = loadLocalManifest(),
               FileManager.default.fileExists(atPath: modelFilePath.path) {
                state = .updateAvailable(remote: remote.version, local: local.version)
            } else {
                state = .notDownloaded
            }
        } catch {
            logger.warning("[Gemma] manifest 检查失败: \(error.localizedDescription)")
            // manifest 获取失败不阻塞：如本地有模型就继续用
            if resolvedModelPath != nil { loadModel() }
        }
    }

    // MARK: - 下载

    func downloadModel() async {
        guard !isModelReady else { return }
        state = .downloading(progress: 0)
        logger.info("[Gemma] 开始下载...")

        do {
            let manifest = try await fetchManifest()
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

            guard let downloadURL = URL(string: manifest.downloadUrl) else {
                throw GemmaError.downloadFailed("模型下载 URL 无效")
            }

            // ① 下载模型文件（带进度）
            var request = URLRequest(url: downloadURL)
            Self.authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

            let delegate = DownloadProgressDelegate(
                expectedBytes: manifest.sizeBytes
            ) { [weak self] progress in
                Task { @MainActor in self?.state = .downloading(progress: progress) }
            }
            let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
            let (tempURL, response) = try await session.download(for: request, delegate: delegate)

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw GemmaError.downloadFailed("HTTP \(http.statusCode)")
            }

            // ② SHA-256 校验
            state = .verifying
            logger.info("[Gemma] 校验 SHA-256...")
            let fileHash = try sha256(of: tempURL)
            guard fileHash == manifest.sha256 else {
                throw GemmaError.integrityCheckFailed(
                    expected: String(manifest.sha256.prefix(12)),
                    got: String(fileHash.prefix(12))
                )
            }
            logger.info("[Gemma] SHA-256 校验通过")

            // ③ 原子替换本地文件
            let fm = FileManager.default
            if fm.fileExists(atPath: modelFilePath.path) { try fm.removeItem(at: modelFilePath) }
            try fm.moveItem(at: tempURL, to: modelFilePath)

            // ④ 保存 manifest 到本地（记录版本）
            let manifestData = try JSONEncoder().encode(manifest)
            try manifestData.write(to: localManifestPath, options: .atomic)

            logger.info("[Gemma] 下载完成 → \(manifest.version)")
            loadModel()
        } catch {
            logger.error("[Gemma] 下载失败: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - 加载

    /// 同步加载（仅供下载完成后 / checkForUpdate 内部使用）
    private func loadModel() {
        guard let path = resolvedModelPath else {
            state = .notDownloaded
            return
        }
        logger.info("[Gemma] 加载模型: \(path)")

        do {
            let options = LlmInference.Options(modelPath: path)
            options.maxTokens = 512

            llmInference = try LlmInference(options: options)
            state = .ready
            logger.info("[Gemma] 模型加载完成")
        } catch {
            logger.error("[Gemma] 模型加载失败: \(error.localizedDescription)")
            state = .error("模型加载失败：\(error.localizedDescription)")
        }
    }

    /// 异步加载——在后台线程执行重量级 init，避免阻塞主线程
    private func loadModelAsync() async {
        guard let path = resolvedModelPath else {
            state = .notDownloaded
            return
        }
        state = .checkingManifest  // 复用状态表示"加载中"
        logger.info("[Gemma] 异步加载模型: \(path)")
        let loadStart = CFAbsoluteTimeGetCurrent()

        do {
            let options = LlmInference.Options(modelPath: path)
            options.maxTokens = 512
            // LlmInference 初始化可能耗费数秒（加载 2.5 GB 权重），放到后台
            let inference = try await Task.detached(priority: .userInitiated) {
                try LlmInference(options: options)
            }.value
            llmInference = inference
            state = .ready
            let elapsed = CFAbsoluteTimeGetCurrent() - loadStart
            logger.info("[Gemma] 异步模型加载完成，耗时: \(String(format: "%.2f", elapsed))s")
            recordLoadTime(elapsed)
        } catch {
            logger.error("[Gemma] 异步模型加载失败: \(error.localizedDescription)")
            state = .error("模型加载失败：\(error.localizedDescription)")
        }
    }

    /// 记录一次模型加载耗时，持久化到 UserDefaults，并更新可观察属性
    private func recordLoadTime(_ seconds: Double) {
        var samples = Self.loadSamples
        samples.append(seconds)
        if samples.count > Self.maxSamples { samples = Array(samples.suffix(Self.maxSamples)) }
        UserDefaults.standard.set(samples, forKey: Self.loadTimeSamplesKey)
        lastLoadTimeSeconds = seconds
        loadCount = samples.count
    }

    /// 记录一次推理耗时
    private func recordInferenceTime(_ seconds: Double) {
        var samples = Self.inferenceSamples
        samples.append(seconds)
        if samples.count > Self.maxSamples { samples = Array(samples.suffix(Self.maxSamples)) }
        UserDefaults.standard.set(samples, forKey: Self.inferenceTimeSamplesKey)
        lastInferenceTimeSeconds = seconds
        inferenceCount = samples.count
    }

    // MARK: - 推理

    /// 单轮文本生成（nonisolated —— 调用方应在后台 Task 中调用）。
    /// 首次调用时自动触发异步加载。
    nonisolated func generate(prompt: String) async throws -> String {
        // 确保模型已加载（懒加载）
        await ensureLoaded()
        let inference: LlmInference = try await MainActor.run {
            guard let inf = llmInference else { throw GemmaError.modelNotReady }
            return inf
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        let sessionOptions = LlmInference.Session.Options()
        sessionOptions.topk = 20
        sessionOptions.topp = 0.9
        sessionOptions.temperature = 0.1   // 低温 → 稳定的 JSON 输出

        let session = try LlmInference.Session(llmInference: inference, options: sessionOptions)
        try session.addQueryChunk(inputText: prompt)

        var fullResponse = ""
        let stream = session.generateResponseAsync()
        for try await chunk in stream {
            fullResponse += chunk
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("[Gemma] 推理耗时: \(String(format: "%.2f", elapsed))s, 响应长度: \(fullResponse.count)")

        // 记录推理耗时 + 调度延迟卸载
        await MainActor.run {
            recordInferenceTime(elapsed)
            scheduleAutoUnload()
        }

        return fullResponse
    }

    // MARK: - 删除

    func deleteModel() {
        llmInference = nil
        try? FileManager.default.removeItem(at: modelDirectory)
        state = .notDownloaded
        logger.info("[Gemma] 模型已删除")
    }

    // MARK: - Private helpers

    private func fetchManifest() async throws -> ModelManifest {
        guard let url = URL(string: Self.manifestURL) else {
            throw GemmaError.downloadFailed("manifest URL 无效")
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        Self.authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GemmaError.downloadFailed("获取 manifest 失败（HTTP \(http.statusCode)）")
        }
        return try JSONDecoder().decode(ModelManifest.self, from: data)
    }

    private func loadLocalManifest() -> ModelManifest? {
        guard let data = try? Data(contentsOf: localManifestPath) else { return nil }
        return try? JSONDecoder().decode(ModelManifest.self, from: data)
    }

    /// 流式计算文件 SHA-256（不会把 2.5 GB 全部加载到内存）
    private func sha256(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { handle.closeFile() }
        var hasher = SHA256()
        let bufferSize = 1_048_576 // 1 MB
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: bufferSize)
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 错误

    enum GemmaError: LocalizedError {
        case modelNotReady
        case downloadFailed(String)
        case integrityCheckFailed(expected: String, got: String)

        var errorDescription: String? {
            switch self {
            case .modelNotReady:
                return "Gemma 模型未就绪"
            case .downloadFailed(let msg):
                return "下载失败：\(msg)"
            case .integrityCheckFailed(let expected, let got):
                return "文件校验失败：预期 \(expected)…，实际 \(got)…"
            }
        }
    }
}

// MARK: - Manifest 数据模型

struct ModelManifest: Codable, Sendable {
    let modelId: String
    let version: String
    let backend: String
    let filename: String
    let sizeBytes: Int64
    let sha256: String
    let downloadUrl: String
    let minAppVersion: String
    let notes: String

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case version
        case backend
        case filename
        case sizeBytes = "size_bytes"
        case sha256
        case downloadUrl = "download_url"
        case minAppVersion = "min_app_version"
        case notes
    }
}

// MARK: - 下载进度代理

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    let expectedBytes: Int64
    let onProgress: @Sendable (Double) -> Void

    init(expectedBytes: Int64, onProgress: @escaping @Sendable (Double) -> Void) {
        self.expectedBytes = expectedBytes
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // 优先用服务端 Content-Length，缺失时 fallback 到 manifest.sizeBytes
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : expectedBytes
        guard total > 0 else { return }
        onProgress(min(Double(totalBytesWritten) / Double(total), 1.0))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // download(for:) 已经处理了临时文件
    }
}
