import Foundation

struct SampleReceipt: Identifiable {
    let id = UUID()
    let title: String
    let source: ReceiptSource
    let rawText: String
    let preview: String
}
