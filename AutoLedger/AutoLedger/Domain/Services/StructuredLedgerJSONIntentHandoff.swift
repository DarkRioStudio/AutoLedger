import AutoLedgerCore
import Foundation

struct StructuredLedgerJSONIntentHandoff: Codable, Identifiable, Equatable {
    let id: UUID
    var draft: StructuredLedgerJSONDraft
    var rawJSON: String

    init(id: UUID = UUID(), draft: StructuredLedgerJSONDraft, rawJSON: String) {
        self.id = id
        self.draft = draft
        self.rawJSON = rawJSON
    }
}

enum StructuredLedgerJSONIntentHandoffStore {
    private static let key = "AutoLedger.pendingStructuredLedgerJSONIntentHandoff"

    static func save(_ handoff: StructuredLedgerJSONIntentHandoff) {
        guard let data = try? JSONEncoder().encode(handoff) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func consume() -> StructuredLedgerJSONIntentHandoff? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let handoff = try? JSONDecoder().decode(StructuredLedgerJSONIntentHandoff.self, from: data) else {
            return nil
        }
        UserDefaults.standard.removeObject(forKey: key)
        return handoff
    }
}
