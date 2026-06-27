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
    case imapStatus(String)
    case connectionClosed
    case invalidIMAPResponse
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
        case .imapStatus(let message):
            return String(format: String(localized: "hotel_stay.email.error.imap_status_format"), message)
        case .connectionClosed:
            return String(localized: "hotel_stay.email.error.connection_closed")
        case .invalidIMAPResponse:
            return String(localized: "hotel_stay.email.error.invalid_response")
        case .unsupportedAttachment:
            return String(localized: "hotel_stay.email.error.unsupported_attachment")
        case .emptyPDFText:
            return String(localized: "hotel_stay.email.error.empty_pdf_text")
        }
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

enum HotelFolioEmailDemoMode {
    static var isAvailable: Bool { true }

    static func makeMessage() -> HotelFolioEmailMessage {
        HotelFolioEmailDemoFixture.message(pdfData: makePDFData())
    }

    static func isDemoMessage(_ message: HotelFolioEmailMessage) -> Bool {
        message.uid == HotelFolioEmailDemoFixture.uid
            && message.messageID == HotelFolioEmailDemoFixture.messageID
    }

    static func makeDraft(
        message: HotelFolioEmailMessage,
        attachment: HotelFolioEmailAttachment,
        targetLedgerID: String?
    ) throws -> HotelStayDraft {
        guard isDemoMessage(message),
              attachment.fileName == HotelFolioEmailDemoFixture.attachmentFileName else {
            throw HotelFolioEmailImportError.unsupportedAttachment
        }
        return try HotelFolioEmailDraftFactory().makeDraft(
            message: message,
            attachment: attachment,
            extractedText: HotelFolioEmailDemoFixture.extractedText,
            targetLedgerID: targetLedgerID
        )
    }

    nonisolated private static func makePDFData() -> Data {
        #if canImport(UIKit)
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        return renderer.pdfData { context in
            context.beginPage()
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.label
            ]
            NSAttributedString(
                string: "AutoLedger Demo Hotel Folio",
                attributes: titleAttributes
            ).draw(in: CGRect(x: 72, y: 64, width: 468, height: 32))

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 4
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph
            ]
            NSAttributedString(
                string: HotelFolioEmailDemoFixture.extractedText,
                attributes: bodyAttributes
            ).draw(in: CGRect(x: 72, y: 112, width: 468, height: 560))
        }
        #else
        return Data(HotelFolioEmailDemoFixture.extractedText.utf8)
        #endif
    }
}

struct HotelFolioIMAPClient: Sendable {
    private let parser: HotelFolioEmailMessageParser
    private let filter: HotelFolioEmailCandidateFilter

    init(
        parser: HotelFolioEmailMessageParser = HotelFolioEmailMessageParser(),
        filter: HotelFolioEmailCandidateFilter = HotelFolioEmailCandidateFilter()
    ) {
        self.parser = parser
        self.filter = filter
    }

    func scan(settings: HotelEmailAccountSettings, credential: String) async throws -> [HotelFolioEmailMessage] {
        let settings = settings.normalized
        guard !settings.emailAddress.isEmpty, !settings.imapHost.isEmpty, !credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HotelFolioEmailImportError.invalidSettings
        }

        let session = HotelFolioIMAPSession(
            host: settings.imapHost,
            port: settings.imapPort,
            useTLS: settings.useTLS
        )
        try await session.connect()
        defer {
            Task {
                try? await session.logout()
                await session.close()
            }
        }

        try await session.login(username: settings.emailAddress, password: credential)
        try await session.selectMailbox("INBOX")
        let sinceDate = Calendar.current.date(byAdding: .day, value: -settings.searchDays, to: Date()) ?? Date()
        let uids = try await session.searchUIDs(since: sinceDate)
            .suffix(settings.maxMessages)
            .reversed()

        var candidates: [HotelFolioEmailMessage] = []
        for uid in uids {
            do {
                let rawMessage = try await session.fetchRFC822(uid: uid)
                let message = try parser.parse(rawMessage: rawMessage, uid: uid)
                if filter.isLikelyHotelFolio(message) {
                    candidates.append(message)
                }
            } catch {
                continue
            }
        }
        return candidates
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
        guard let searchLine = response
            .split(separator: "\n")
            .map(String.init)
            .first(where: { $0.uppercased().hasPrefix("* SEARCH") }) else {
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
            throw HotelFolioEmailImportError.invalidIMAPResponse
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
        guard let finalLine = response
            .split(separator: "\n")
            .map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) })
            .last(where: { $0.hasPrefix(tag) }) else {
            throw HotelFolioEmailImportError.invalidIMAPResponse
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
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: HotelFolioEmailImportError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func readGreeting() async throws -> String {
        try await readUntil { text in
            text.contains("\r\n") || text.contains("\n")
        }
    }

    private func readResponse(tag: String) async throws -> String {
        try await readUntil { text in
            text.contains("\r\n\(tag) ") || text.contains("\n\(tag) ")
        }
    }

    private func readUntil(_ isComplete: @escaping @Sendable (String) -> Bool) async throws -> String {
        var buffer = Data()
        while true {
            let chunk = try await receiveChunk()
            buffer.append(chunk)
            let text = String(decoding: buffer, as: UTF8.self)
            if isComplete(text) {
                return text
            }
        }
    }

    private func receiveChunk() async throws -> Data {
        guard let connection else {
            throw HotelFolioEmailImportError.connectionClosed
        }

        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: HotelFolioEmailImportError.connectionFailed(error.localizedDescription))
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: HotelFolioEmailImportError.connectionClosed)
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    private func extractFirstLiteral(from response: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\{(\d+)\}\r?\n"#) else {
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
}
