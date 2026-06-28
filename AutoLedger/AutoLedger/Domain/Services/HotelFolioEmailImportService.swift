import AutoLedgerCore
import Foundation
import Network
import PDFKit
import Security
#if canImport(UIKit)
import UIKit
#endif

enum HotelEmailAccountSettingsStore {
    private static let storageKey = "hotelFolioEmailAccountSettings.v1"

    static var current: HotelEmailAccountSettings {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey),
                  let settings = try? JSONDecoder().decode(HotelEmailAccountSettings.self, from: data) else {
                return .qq()
            }
            return settings.normalized
        }
        set {
            save(newValue)
        }
    }

    static func save(_ settings: HotelEmailAccountSettings) {
        guard let data = try? JSONEncoder().encode(settings.normalized) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

enum HotelFolioEmailImportError: Error, Sendable {
    case invalidSettings
    case missingCredential
    case keychainStatus(OSStatus)
    case connectionFailed(String)
    case operationTimeout(String)
    case imapStatus(String)
    case connectionClosed
    case invalidIMAPResponse(operation: String, responseSummary: String)
    case unsupportedAttachment
    case emptyPDFText
}

extension HotelFolioEmailImportError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidSettings:
            return String(localized: "hotel_stay.email.error.invalid_settings")
        case .missingCredential:
            return String(localized: "hotel_stay.email.error.missing_credential")
        case .keychainStatus(let status):
            return String(format: String(localized: "hotel_stay.email.error.keychain_status_format"), Int(status))
        case .connectionFailed(let message):
            return String(format: String(localized: "hotel_stay.email.error.connection_failed_format"), message)
        case .operationTimeout(let operation):
            return String(format: String(localized: "hotel_stay.email.error.timeout_format"), operation)
        case .imapStatus(let message):
            return String(format: String(localized: "hotel_stay.email.error.imap_status_format"), message)
        case .connectionClosed:
            return String(localized: "hotel_stay.email.error.connection_closed")
        case .invalidIMAPResponse(let operation, let responseSummary):
            return String(
                format: String(localized: "hotel_stay.email.error.invalid_response_format"),
                operation,
                responseSummary
            )
        case .unsupportedAttachment:
            return String(localized: "hotel_stay.email.error.unsupported_attachment")
        case .emptyPDFText:
            return String(localized: "hotel_stay.email.error.empty_pdf_text")
        }
    }
}

enum HotelFolioEmailScanPhase: Sendable {
    case connecting
    case authenticating
    case selectingMailbox
    case keywordSearching
    case keywordSearchCompleted(Int)
    case searching
    case foundMessages(Int)
    case fetching(index: Int, total: Int)
    case candidateAccepted(subject: String)
    case messageSkipped(uid: String)
    case completed(Int)
}

struct HotelFolioEmailScanProgress: Sendable {
    let phase: HotelFolioEmailScanPhase
    let debugSummary: String
    let rawText: String

    init(phase: HotelFolioEmailScanPhase, debugSummary: String, rawText: String = "") {
        self.phase = phase
        self.debugSummary = debugSummary
        self.rawText = rawText
    }
}

enum HotelEmailCredentialStore {
    private static let service = "top.darkrio326.AutoLedger.hotelEmail"

    static func hasStoredCredential(for emailAddress: String) -> Bool {
        (try? readCredential(for: emailAddress))?.isEmpty == false
    }

    static func saveCredential(_ value: String, for emailAddress: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let data = Data(trimmed.utf8)
        deleteCredential(for: emailAddress)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: emailAddress),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw HotelFolioEmailImportError.keychainStatus(status)
        }
    }

    static func readCredential(for emailAddress: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: emailAddress),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw HotelFolioEmailImportError.keychainStatus(status)
        }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteCredential(for emailAddress: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: emailAddress)
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func account(for emailAddress: String) -> String {
        let trimmed = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? "default" : trimmed
    }
}

struct HotelFolioEmailAttachmentImporter: Sendable {
    private let textExtractor: @Sendable (Data) throws -> String
    private let draftFactory: HotelFolioEmailDraftFactory

    init(
        textExtractor: @escaping @Sendable (Data) throws -> String = HotelFolioEmailAttachmentImporter.extractPDFText,
        draftFactory: HotelFolioEmailDraftFactory = HotelFolioEmailDraftFactory()
    ) {
        self.textExtractor = textExtractor
        self.draftFactory = draftFactory
    }

    func makeDraft(
        message: HotelFolioEmailMessage,
        attachment: HotelFolioEmailAttachment,
        targetLedgerID: String?
    ) throws -> HotelStayDraft {
        guard attachment.mimeType == "application/pdf" || attachment.fileName.lowercased().hasSuffix(".pdf") else {
            throw HotelFolioEmailImportError.unsupportedAttachment
        }
        let text = try textExtractor(attachment.data)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HotelFolioEmailImportError.emptyPDFText
        }
        return try draftFactory.makeDraft(
            message: message,
            attachment: attachment,
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

struct HotelFolioIMAPClient: Sendable {
    private let parser: HotelFolioEmailMessageParser
    private let filter: HotelFolioEmailCandidateFilter
    private let operationTimeoutSeconds: UInt64

    init(
        parser: HotelFolioEmailMessageParser = HotelFolioEmailMessageParser(),
        filter: HotelFolioEmailCandidateFilter = HotelFolioEmailCandidateFilter(),
        operationTimeoutSeconds: UInt64 = 30
    ) {
        self.parser = parser
        self.filter = filter
        self.operationTimeoutSeconds = operationTimeoutSeconds
    }

    func scan(
        settings: HotelEmailAccountSettings,
        credential: String,
        onProgress: @escaping (HotelFolioEmailScanProgress) -> Void = { _ in }
    ) async throws -> [HotelFolioEmailMessage] {
        let settings = settings.normalized
        guard !settings.emailAddress.isEmpty, !settings.imapHost.isEmpty, !credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HotelFolioEmailImportError.invalidSettings
        }

        onProgress(
            HotelFolioEmailScanProgress(
                phase: .connecting,
                debugSummary: "邮箱水单扫描：连接 \(settings.imapHost):\(settings.imapPort) · TLS=\(settings.useTLS)"
            )
        )
        let session = HotelFolioIMAPSession(
            host: settings.imapHost,
            port: settings.imapPort,
            useTLS: settings.useTLS
        )
        try await withIMAPTimeout(operation: "connect") {
            try await session.connect()
        }
        defer {
            Task {
                try? await session.logout()
                await session.close()
            }
        }

        onProgress(
            HotelFolioEmailScanProgress(
                phase: .authenticating,
                debugSummary: "邮箱水单扫描：连接成功，开始登录 \(settings.emailAddress)"
            )
        )
        try await withIMAPTimeout(operation: "login") {
            try await session.login(username: settings.emailAddress, password: credential)
        }
        onProgress(
            HotelFolioEmailScanProgress(
                phase: .selectingMailbox,
                debugSummary: "邮箱水单扫描：登录成功，选择 INBOX"
            )
        )
        try await withIMAPTimeout(operation: "select INBOX") {
            try await session.selectMailbox("INBOX")
        }
        let sinceDate = Calendar.current.date(byAdding: .day, value: -settings.searchDays, to: Date()) ?? Date()
        onProgress(
            HotelFolioEmailScanProgress(
                phase: .keywordSearching,
                debugSummary: "邮箱水单扫描：按酒店水单关键词搜索最近 \(settings.searchDays) 天邮件"
            )
        )
        let candidateUIDs = try await withIMAPTimeout(operation: "search hotel candidates") {
            try await session.searchHotelCandidateUIDs(since: sinceDate, limit: settings.maxMessages)
        }
        onProgress(
            HotelFolioEmailScanProgress(
                phase: .keywordSearchCompleted(candidateUIDs.count),
                debugSummary: "邮箱水单扫描：关键词候选 UID=\(candidateUIDs.count)"
            )
        )
        onProgress(
            HotelFolioEmailScanProgress(
                phase: .searching,
                debugSummary: "邮箱水单扫描：读取最近邮件作为兜底"
            )
        )
        let fallbackLimit = candidateUIDs.isEmpty ? settings.maxMessages : min(settings.maxMessages, 20)
        let fallbackUIDs = try await withIMAPTimeout(operation: "search recent fallback") {
            try await session.searchUIDs(since: sinceDate)
        }
            .suffix(fallbackLimit)
            .reversed()
        let uids = mergeCandidateUIDs(
            candidateUIDs: candidateUIDs,
            fallbackUIDs: Array(fallbackUIDs),
            limit: settings.maxMessages
        )
        onProgress(
            HotelFolioEmailScanProgress(
                phase: .foundMessages(uids.count),
                debugSummary: "邮箱水单扫描：找到 \(uids.count) 封待检查邮件 · keyword=\(candidateUIDs.count) · fallback=\(fallbackUIDs.count) · 最多读取 \(settings.maxMessages) 封"
            )
        )

        var candidates: [HotelFolioEmailMessage] = []
        for (index, uid) in uids.enumerated() {
            onProgress(
                HotelFolioEmailScanProgress(
                    phase: .fetching(index: index + 1, total: uids.count),
                    debugSummary: "邮箱水单扫描：读取第 \(index + 1)/\(uids.count) 封邮件 · uid=\(uid)"
                )
            )
            do {
                let rawMessage = try await withIMAPTimeout(operation: "fetch \(uid)") {
                    try await session.fetchRFC822(uid: uid)
                }
                let message = try parser.parse(rawMessage: rawMessage, uid: uid)
                if filter.isLikelyHotelFolio(message) {
                    candidates.append(message)
                    onProgress(
                        HotelFolioEmailScanProgress(
                            phase: .candidateAccepted(subject: message.subject),
                            debugSummary: "邮箱水单扫描：命中候选水单邮件 · uid=\(uid) · subject=\(message.subject)",
                            rawText: message.subject
                        )
                    )
                } else {
                    onProgress(
                        HotelFolioEmailScanProgress(
                            phase: .messageSkipped(uid: uid),
                            debugSummary: "邮箱水单扫描：跳过非候选邮件 · uid=\(uid)"
                        )
                    )
                }
            } catch {
                onProgress(
                    HotelFolioEmailScanProgress(
                        phase: .messageSkipped(uid: uid),
                        debugSummary: "邮箱水单扫描：跳过邮件 · uid=\(uid) · error=\(error.localizedDescription)"
                    )
                )
                continue
            }
        }
        onProgress(
            HotelFolioEmailScanProgress(
                phase: .completed(candidates.count),
                debugSummary: "邮箱水单扫描：完成 · candidates=\(candidates.count)"
            )
        )
        return candidates
    }

    private func mergeCandidateUIDs(candidateUIDs: [String], fallbackUIDs: [String], limit: Int) -> [String] {
        var merged: [String] = []
        var seen: Set<String> = []
        for uid in candidateUIDs + fallbackUIDs {
            guard merged.count < limit else { break }
            guard seen.insert(uid).inserted else { continue }
            merged.append(uid)
        }
        return merged
    }

    private func withIMAPTimeout<T: Sendable>(
        operation: String,
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await work()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: operationTimeoutSeconds * 1_000_000_000)
                throw HotelFolioEmailImportError.operationTimeout(operation)
            }

            guard let result = try await group.next() else {
                throw HotelFolioEmailImportError.connectionClosed
            }
            group.cancelAll()
            return result
        }
    }
}

private final class HotelFolioIMAPConnectContinuation: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var didResume = false
    private let continuation: CheckedContinuation<Void, Error>

    nonisolated init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    nonisolated func resume() {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume()
    }

    nonisolated func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(throwing: error)
    }
}

private final class HotelFolioIMAPDataContinuation: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var didResume = false
    private let continuation: CheckedContinuation<Data, Error>

    nonisolated init(_ continuation: CheckedContinuation<Data, Error>) {
        self.continuation = continuation
    }

    nonisolated func resume(returning data: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(returning: data)
    }

    nonisolated func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(throwing: error)
    }
}

private enum HotelFolioIMAPResponseScanner {
    nonisolated static func isTaggedResponseComplete(_ data: Data, tag: String) -> Bool {
        let bytes = Array(data)
        let tagBytes = Array(tag.utf8)
        var index = 0

        while index < bytes.count {
            guard let lineEnd = lineEnd(in: bytes, from: index) else {
                return false
            }

            let line = Array(bytes[index..<lineEnd.contentEnd])
            if lineStartsWithTag(line, tagBytes: tagBytes) {
                return true
            }

            index = lineEnd.nextIndex
            if let length = literalLength(in: line) {
                let literalEnd = index + length
                guard literalEnd <= bytes.count else {
                    return false
                }
                index = literalEnd
            }
        }

        return false
    }

    nonisolated static func taggedCompletionLine(in response: String, tag: String) -> String? {
        response
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .last { line in
                line.hasPrefix("\(tag) ") || line.hasPrefix("\(tag)\t")
            }
    }

    nonisolated static func safeSummary(of response: String, tag: String? = nil) -> String {
        let lines = response.split(separator: "\n", omittingEmptySubsequences: false)
        let tagged = tag.map { taggedCompletionLine(in: response, tag: $0) != nil }
        let uppercased = response.uppercased()
        let flags: [String] = [
            "search=\(uppercased.contains("* SEARCH") ? "yes" : "no")",
            "fetch=\(uppercased.contains(" FETCH ") ? "yes" : "no")",
            "bye=\(uppercased.contains("* BYE") ? "yes" : "no")"
        ]
        let taggedText = tagged.map { "tagged=\($0 ? "yes" : "no")" } ?? "tagged=unknown"
        let summaryItems = [
            "bytes=\(response.utf8.count)",
            "lines=\(lines.count)",
            "literals=\(literalMarkerCount(in: response))",
            taggedText
        ] + flags
        return summaryItems.joined(separator: ", ")
    }

    nonisolated private static func lineStartsWithTag(_ line: [UInt8], tagBytes: [UInt8]) -> Bool {
        guard line.count > tagBytes.count else { return false }
        guard line.prefix(tagBytes.count).elementsEqual(tagBytes) else { return false }
        let separator = line[tagBytes.count]
        return separator == UInt8(ascii: " ") || separator == UInt8(ascii: "\t")
    }

    nonisolated private static func literalLength(in line: [UInt8]) -> Int? {
        guard let openBraceIndex = line.lastIndex(of: UInt8(ascii: "{")),
              line.last == UInt8(ascii: "}") else {
            return nil
        }

        let payload = line[line.index(after: openBraceIndex)..<line.index(before: line.endIndex)]
        let digits = payload.last == UInt8(ascii: "+") ? payload.dropLast() : payload[...]
        guard !digits.isEmpty,
              digits.allSatisfy({ $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }) else {
            return nil
        }

        return Int(String(decoding: digits, as: UTF8.self))
    }

    nonisolated private static func literalMarkerCount(in response: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: #"(?:~)?\{\d+\+?\}"#) else {
            return 0
        }
        let range = NSRange(response.startIndex..<response.endIndex, in: response)
        return regex.numberOfMatches(in: response, range: range)
    }

    nonisolated private static func lineEnd(in bytes: [UInt8], from start: Int) -> (contentEnd: Int, nextIndex: Int)? {
        var index = start
        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "\n") {
                let contentEnd = index > start && bytes[index - 1] == UInt8(ascii: "\r") ? index - 1 : index
                return (contentEnd, index + 1)
            }
            index += 1
        }
        return nil
    }
}

private extension Data {
    nonisolated var containsLineBreak: Bool {
        contains(UInt8(ascii: "\n"))
    }
}

private extension String {
    nonisolated var isASCIIOnly: Bool {
        unicodeScalars.allSatisfy(\.isASCII)
    }
}

private struct HotelFolioIMAPSearchCriterion: Sendable {
    let fragment: String
    let requiresUTF8: Bool
}

private actor HotelFolioIMAPSession {
    private let host: String
    private let port: Int
    private let useTLS: Bool
    private let queue = DispatchQueue(label: "top.darkrio326.AutoLedger.hotelFolioIMAP")
    private var connection: NWConnection?
    private var tagIndex = 0

    init(host: String, port: Int, useTLS: Bool) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
    }

    func connect() async throws {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw HotelFolioEmailImportError.invalidSettings
        }
        let parameters: NWParameters = useTLS ? .tls : .tcp
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: nwPort,
            using: parameters
        )
        self.connection = connection

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resumeOnce = HotelFolioIMAPConnectContinuation(continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resumeOnce.resume()
                case .failed(let error):
                    resumeOnce.resume(throwing: HotelFolioEmailImportError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    resumeOnce.resume(throwing: HotelFolioEmailImportError.connectionClosed)
                default:
                    break
                }
            }
            queue.asyncAfter(deadline: .now() + 30) {
                resumeOnce.resume(throwing: HotelFolioEmailImportError.operationTimeout("connect"))
            }
            connection.start(queue: queue)
        }
        _ = try await readGreeting()
    }

    func login(username: String, password: String) async throws {
        _ = try await execute("LOGIN \(quote(username)) \(quote(password))")
    }

    func selectMailbox(_ mailbox: String) async throws {
        _ = try await execute("SELECT \(quote(mailbox))")
    }

    func searchUIDs(since date: Date) async throws -> [String] {
        try await searchUIDs(since: date, criterion: nil)
    }

    func searchHotelCandidateUIDs(since date: Date, limit: Int) async throws -> [String] {
        var merged: [String] = []
        var seen: Set<String> = []
        for criterion in candidateSearchCriteria {
            guard merged.count < limit else { break }
            do {
                let uids = try await searchUIDs(
                    since: date,
                    criterion: criterion.fragment,
                    usesUTF8: criterion.requiresUTF8
                )
                    .reversed()
                for uid in uids {
                    guard merged.count < limit else { break }
                    guard seen.insert(uid).inserted else { continue }
                    merged.append(uid)
                }
            } catch {
                continue
            }
        }
        return merged
    }

    private func searchUIDs(
        since date: Date,
        criterion: String?,
        usesUTF8: Bool = false
    ) async throws -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd-MMM-yyyy"
        let criterionText = criterion.map { " \($0)" } ?? ""
        let command: String
        if usesUTF8 {
            command = "UID SEARCH CHARSET UTF-8 SINCE \(formatter.string(from: date))\(criterionText)"
        } else {
            command = "UID SEARCH SINCE \(formatter.string(from: date))\(criterionText)"
        }
        let response = try await execute(command)
        return parseSearchUIDs(from: response)
    }

    private func parseSearchUIDs(from response: String) -> [String] {
        let searchLines = response
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let searchLine = searchLines.first(where: { $0.uppercased().hasPrefix("* SEARCH") }) else {
            return []
        }
        return searchLine
            .split(separator: " ")
            .dropFirst()
            .map(String.init)
    }

    private var candidateSearchCriteria: [HotelFolioIMAPSearchCriterion] {
        let highSignalKeywords = [
            "Folio",
            "Hotel",
            "Marriott",
            "账单",
            "電子賬單",
            "电子账单"
        ]
        return highSignalKeywords.flatMap { keyword in
            [
                HotelFolioIMAPSearchCriterion(fragment: "SUBJECT \(quote(keyword))", requiresUTF8: !keyword.isASCIIOnly),
                HotelFolioIMAPSearchCriterion(fragment: "TEXT \(quote(keyword))", requiresUTF8: !keyword.isASCIIOnly)
            ]
        }
    }

    func fetchRFC822(uid: String) async throws -> String {
        let response = try await execute("UID FETCH \(uid) (RFC822)")
        guard let rawMessage = extractFirstLiteral(from: response) else {
            throw HotelFolioEmailImportError.invalidIMAPResponse(
                operation: "fetch message",
                responseSummary: HotelFolioIMAPResponseScanner.safeSummary(of: response)
            )
        }
        return rawMessage
    }

    func logout() async throws {
        _ = try await execute("LOGOUT")
    }

    func close() {
        connection?.cancel()
        connection = nil
    }

    private func execute(_ command: String) async throws -> String {
        tagIndex += 1
        let tag = String(format: "A%04d", tagIndex)
        try await send("\(tag) \(command)\r\n")
        let response = try await readResponse(tag: tag)
        guard let finalLine = HotelFolioIMAPResponseScanner.taggedCompletionLine(in: response, tag: tag) else {
            throw HotelFolioEmailImportError.invalidIMAPResponse(
                operation: commandDebugName(for: command),
                responseSummary: HotelFolioIMAPResponseScanner.safeSummary(of: response, tag: tag)
            )
        }
        guard finalLine.uppercased().contains(" OK") else {
            throw HotelFolioEmailImportError.imapStatus(finalLine)
        }
        return response
    }

    private func send(_ string: String) async throws {
        guard let data = string.data(using: .utf8), let connection else {
            throw HotelFolioEmailImportError.connectionClosed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resumeOnce = HotelFolioIMAPConnectContinuation(continuation)
            queue.asyncAfter(deadline: .now() + 30) {
                resumeOnce.resume(throwing: HotelFolioEmailImportError.operationTimeout("send"))
            }
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    resumeOnce.resume(throwing: HotelFolioEmailImportError.connectionFailed(error.localizedDescription))
                } else {
                    resumeOnce.resume()
                }
            })
        }
    }

    private func readGreeting() async throws -> String {
        try await readUntil { data in
            data.containsLineBreak
        }
    }

    private func readResponse(tag: String) async throws -> String {
        try await readUntil { data in
            HotelFolioIMAPResponseScanner.isTaggedResponseComplete(data, tag: tag)
        }
    }

    private func readUntil(_ isComplete: @escaping @Sendable (Data) -> Bool) async throws -> String {
        var buffer = Data()
        while true {
            let chunk = try await receiveChunk()
            buffer.append(chunk)
            if isComplete(buffer) {
                return String(decoding: buffer, as: UTF8.self)
            }
        }
    }

    private func receiveChunk() async throws -> Data {
        guard let connection else {
            throw HotelFolioEmailImportError.connectionClosed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let resumeOnce = HotelFolioIMAPDataContinuation(continuation)
            queue.asyncAfter(deadline: .now() + 30) {
                resumeOnce.resume(throwing: HotelFolioEmailImportError.operationTimeout("receive"))
            }
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
                if let error {
                    resumeOnce.resume(throwing: HotelFolioEmailImportError.connectionFailed(error.localizedDescription))
                } else if let data, !data.isEmpty {
                    resumeOnce.resume(returning: data)
                } else if isComplete {
                    resumeOnce.resume(throwing: HotelFolioEmailImportError.connectionClosed)
                } else {
                    resumeOnce.resume(throwing: HotelFolioEmailImportError.connectionClosed)
                }
            }
        }
    }

    private func extractFirstLiteral(from response: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"(?:~)?\{(\d+)\+?\}\r?\n"#) else {
            return nil
        }
        let range = NSRange(response.startIndex..<response.endIndex, in: response)
        guard let match = regex.firstMatch(in: response, range: range),
              let lengthRange = Range(match.range(at: 1), in: response),
              let contentStart = Range(match.range, in: response)?.upperBound,
              let length = Int(response[lengthRange]) else {
            return nil
        }

        let bytes = response[contentStart...].utf8.prefix(length)
        return String(decoding: bytes, as: UTF8.self)
    }

    private func quote(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private func commandDebugName(for command: String) -> String {
        let uppercased = command.uppercased()
        if uppercased.hasPrefix("LOGIN ") {
            return "login"
        }
        if uppercased.hasPrefix("SELECT ") {
            return "select mailbox"
        }
        if uppercased.hasPrefix("UID SEARCH ") {
            return "search messages"
        }
        if uppercased.hasPrefix("UID FETCH ") {
            return "fetch message"
        }
        if uppercased.hasPrefix("LOGOUT") {
            return "logout"
        }
        return command.split(separator: " ").first.map(String.init) ?? "imap command"
    }
}
