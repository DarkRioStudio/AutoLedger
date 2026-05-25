import AutoLedgerCore
import Foundation

enum ICloudBackupServiceError: LocalizedError {
    case containerUnavailable

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return String(localized: "icloud.error.container_unavailable")
        }
    }
}

struct ICloudBackupService {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func backupURL() throws -> URL {
        guard let container = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            throw ICloudBackupServiceError.containerUnavailable
        }
        let documents = container.appendingPathComponent("Documents", isDirectory: true)
        if !fileManager.fileExists(atPath: documents.path) {
            try fileManager.createDirectory(at: documents, withIntermediateDirectories: true)
        }
        return documents.appendingPathComponent("AutoLedgerBackup.json")
    }

    func write(bundle: BackupBundle) throws -> URL {
        let target = try backupURL()
        let tmp = target.deletingLastPathComponent().appendingPathComponent("AutoLedgerBackup.tmp")
        let data = try encoder.encode(bundle)
        try data.write(to: tmp, options: [.atomic])
        if fileManager.fileExists(atPath: target.path) {
            _ = try fileManager.replaceItemAt(target, withItemAt: tmp)
        } else {
            try fileManager.moveItem(at: tmp, to: target)
        }
        return target
    }

    func readBundleIfAvailable() throws -> BackupBundle? {
        let url = try backupURL()
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let bundle = try decoder.decode(BackupBundle.self, from: data)
        try BackupValidator.validate(bundle)
        return bundle
    }
}
