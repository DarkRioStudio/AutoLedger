import Foundation

public struct SampleReceipt: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let source: ReceiptSource
    public let rawText: String
    public let preview: String

    public init(title: String, source: ReceiptSource, rawText: String, preview: String) {
        self.title = title
        self.source = source
        self.rawText = rawText
        self.preview = preview
    }
}
