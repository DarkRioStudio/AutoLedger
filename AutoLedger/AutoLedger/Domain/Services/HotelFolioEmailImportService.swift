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
    private let operationTimeoutSeconds: UInt64

    init(
        parser: HotelFolioEmailMessageParser = HotelFolioEmailMessageParser(),
        operationTimeoutSeconds: UInt64 = 30
    ) {
        self.parser = parser
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
        let scanScopeSummary = settings.searchDays > 0 ? "days=\(settings.searchDays)" : "all"
        onProgress(
            HotelFolioEmailScanProgress(
                phase: .searching,
                debugSummary: "邮箱水单扫描：扫描时间窗内全部邮件 · \(scanScopeSummary)"
            )
        )
        let uids = try await withIMAPTimeout(operation: "search attachment window") {
            if settings.searchDays > 0 {
                let sinceDate = Calendar.current.date(byAdding: .day, value: -settings.searchDays, to: Date()) ?? Date()
                return try await session.searchUIDs(since: sinceDate)
            }
            return try await session.searchAllUIDs()
        }
            .reversed()
        let maxMessagesSummary = settings.maxMessages > 0 ? "\(settings.maxMessages)" : "全部"
        onProgress(
            HotelFolioEmailScanProgress(
                phase: .foundMessages(uids.count),
                debugSummary: "邮箱水单扫描：找到 \(uids.count) 封时间窗内邮件，开始筛选 PDF 附件 · 最多展示 \(maxMessagesSummary) 封"
            )
        )

        var candidates: [HotelFolioEmailMessage] = []
        for (index, uid) in uids.enumerated() {
            if settings.maxMessages > 0 && candidates.count >= settings.maxMessages {
                onProgress(
                    HotelFolioEmailScanProgress(
                        phase: .completed(candidates.count),
                        debugSummary: "邮箱水单扫描：PDF 附件邮件已达到展示上限 · limit=\(settings.maxMessages)"
                    )
                )
                break
            }
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
                if let pdfMessage = pdfAttachmentMessage(message) {
                    candidates.append(pdfMessage)
                    onProgress(
                        HotelFolioEmailScanProgress(
                            phase: .candidateAccepted(subject: pdfMessage.subject),
                            debugSummary: "邮箱水单扫描：发现 PDF 附件邮件 · uid=\(uid) · subject=\(pdfMessage.subject) · pdf=\(pdfMessage.attachments.count)",
                            rawText: pdfMessage.subject
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

    private func pdfAttachmentMessage(_ message: HotelFolioEmailMessage) -> HotelFolioEmailMessage? {
        let pdfAttachments = message.attachments.filter { attachment in
            attachment.mimeType == "application/pdf" || attachment.fileName.lowercased().hasSuffix(".pdf")
        }
        guard !pdfAttachments.isEmpty else {
            return nil
        }
        return HotelFolioEmailMessage(
            uid: message.uid,
            messageID: message.messageID,
            subject: message.subject,
            from: message.from,
            dateText: message.dateText,
            attachments: pdfAttachments
        )
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
        taggedCompletionLine(in: data, tag: tag) != nil
    }

    nonisolated static func taggedCompletionLine(in data: Data, tag: String) -> String? {
        let bytes = Array(data)
        let tagBytes = Array(tag.utf8)
        var index = 0
        var completionLine: [UInt8]?

        while index < bytes.count {
            guard let lineEnd = lineEnd(in: bytes, from: index) else {
                return completionLine.map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
            }

            let line = Array(bytes[index..<lineEnd.contentEnd])
            if lineStartsWithTag(line, tagBytes: tagBytes) {
                completionLine = line
            }

            index = lineEnd.nextIndex
            if let length = literalLength(in: line) {
                let literalEnd = index + length
                guard literalEnd <= bytes.count else {
                    return nil
                }
                index = literalEnd
            }
        }

        return completionLine.map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    nonisolated static func safeSummary(of response: String, tag: String? = nil) -> String {
        safeSummary(of: Data(response.utf8), tag: tag)
    }

    nonisolated static func safeSummary(of data: Data, tag: String? = nil) -> String {
        let response = String(decoding: data, as: UTF8.self)
        let tagged = tag.map { taggedCompletionLine(in: data, tag: $0) != nil }
        let uppercased = response.uppercased()
        let flags: [String] = [
            "search=\(uppercased.contains("* SEARCH") ? "yes" : "no")",
            "fetch=\(uppercased.contains(" FETCH ") ? "yes" : "no")",
            "bye=\(uppercased.contains("* BYE") ? "yes" : "no")"
        ]
        let taggedText = tagged.map { "tagged=\($0 ? "yes" : "no")" } ?? "tagged=unknown"
        let summaryItems = [
            "bytes=\(data.count)",
            "lines=\(lineCount(in: Array(data)))",
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
            if bytes[index] == UInt8(ascii: "\r") {
                let nextIndex = index + 1
                if nextIndex < bytes.count && bytes[nextIndex] == UInt8(ascii: "\n") {
                    return (index, nextIndex + 1)
                }
                return (index, nextIndex)
            }
            if bytes[index] == UInt8(ascii: "\n") {
                return (index, index + 1)
            }
            index += 1
        }
        return nil
    }

    nonisolated private static func lineCount(in bytes: [UInt8]) -> Int {
        guard !bytes.isEmpty else { return 0 }
        var count = 0
        var index = 0
        while index < bytes.count {
            guard let lineEnd = lineEnd(in: bytes, from: index) else {
                return count + 1
            }
            count += 1
            index = lineEnd.nextIndex
        }
        return count
    }
}

private extension Data {
    nonisolated var containsLineBreak: Bool {
        contains(UInt8(ascii: "\n")) || contains(UInt8(ascii: "\r"))
    }
}

private struct HotelFolioIMAPTaggedResponse: Sendable {
    let text: String
    let finalLine: String
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd-MMM-yyyy"
        let response = try await execute("UID SEARCH SINCE \(formatter.string(from: date))")
        return parseSearchUIDs(from: response)
    }

    func searchAllUIDs() async throws -> [String] {
        let response = try await execute("UID SEARCH ALL")
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
        guard response.finalLine.uppercased().contains(" OK") else {
            throw HotelFolioEmailImportError.imapStatus(response.finalLine)
        }
        return response.text
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

    private func readResponse(tag: String) async throws -> HotelFolioIMAPTaggedResponse {
        let data = try await readUntilData { data in
            HotelFolioIMAPResponseScanner.isTaggedResponseComplete(data, tag: tag)
        }
        guard let finalLine = HotelFolioIMAPResponseScanner.taggedCompletionLine(in: data, tag: tag) else {
            throw HotelFolioEmailImportError.invalidIMAPResponse(
                operation: "imap response",
                responseSummary: HotelFolioIMAPResponseScanner.safeSummary(of: data, tag: tag)
            )
        }
        return HotelFolioIMAPTaggedResponse(
            text: String(decoding: data, as: UTF8.self),
            finalLine: finalLine
        )
    }

    private func readUntil(_ isComplete: @escaping @Sendable (Data) -> Bool) async throws -> String {
        let data = try await readUntilData(isComplete)
        return String(decoding: data, as: UTF8.self)
    }

    private func readUntilData(_ isComplete: @escaping @Sendable (Data) -> Bool) async throws -> Data {
        var buffer = Data()
        while true {
            let chunk = try await receiveChunk()
            buffer.append(chunk)
            if isComplete(buffer) {
                return buffer
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
