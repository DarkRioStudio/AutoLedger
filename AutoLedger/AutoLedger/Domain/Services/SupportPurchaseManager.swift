import Combine
import Foundation
import StoreKit

enum SupportProduct: String, CaseIterable, Identifiable {
    case coffee = "top.darkrio326.AutoLedger.support.coffee"
    case lunch = "top.darkrio326.AutoLedger.support.lunch"
    case sponsor = "top.darkrio326.AutoLedger.support.sponsor"

    var id: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .coffee: 0
        case .lunch: 1
        case .sponsor: 2
        }
    }

    var buttonTitle: String {
        switch self {
        case .coffee:
            String(localized: "support.product.coffee.button")
        case .lunch:
            String(localized: "support.product.lunch.button")
        case .sponsor:
            String(localized: "support.product.sponsor.button")
        }
    }

    var descriptionText: String {
        switch self {
        case .coffee:
            String(localized: "support.product.coffee.description")
        case .lunch:
            String(localized: "support.product.lunch.description")
        case .sponsor:
            String(localized: "support.product.sponsor.description")
        }
    }
}

enum SupportProductLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

struct SupportPurchaseNotice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class SupportPurchaseManager: ObservableObject {
    static let shared = SupportPurchaseManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var loadState: SupportProductLoadState = .idle
    @Published private(set) var purchasingProductID: String?
    @Published var notice: SupportPurchaseNotice?

    @Published private(set) var supportPurchaseCount: Int
    @Published private(set) var lastSupportProductId: String?
    @Published private(set) var lastSupportDate: Date?

    private let userDefaults: UserDefaults
    private var transactionUpdatesTask: Task<Void, Never>?

    private enum DefaultsKey {
        static let supportPurchaseCount = "supportPurchaseCount"
        static let lastSupportProductId = "lastSupportProductId"
        static let lastSupportDate = "lastSupportDate"
        static let processedSupportTransactionIds = "processedSupportTransactionIds"
    }

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.supportPurchaseCount = userDefaults.integer(forKey: DefaultsKey.supportPurchaseCount)
        self.lastSupportProductId = userDefaults.string(forKey: DefaultsKey.lastSupportProductId)
        self.lastSupportDate = userDefaults.object(forKey: DefaultsKey.lastSupportDate) as? Date
    }

    func startTransactionListener() {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.handleTransaction(result, source: .transactionUpdates)
            }
        }
    }

    func loadProducts() async {
        guard loadState != .loading else { return }

        loadState = .loading
        do {
            let fetchedProducts = try await Product.products(for: SupportProduct.allCases.map(\.rawValue))
            products = fetchedProducts.sorted { lhs, rhs in
                sortOrder(for: lhs.id) < sortOrder(for: rhs.id)
            }

            if products.isEmpty {
                loadState = .failed(String(localized: "support.error.no_products"))
            } else {
                loadState = .loaded
            }
        } catch {
            loadState = .failed(String(localized: "support.error.load_failed"))
        }
    }

    func purchase(_ product: Product) async {
        guard purchasingProductID == nil else { return }

        purchasingProductID = product.id
        defer { purchasingProductID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handleTransaction(verification, source: .directPurchase)
            case .pending:
                notice = SupportPurchaseNotice(
                    title: String(localized: "support.purchase.pending.title"),
                    message: String(localized: "support.purchase.pending.message")
                )
            case .userCancelled:
                break
            @unknown default:
                notice = SupportPurchaseNotice(
                    title: String(localized: "support.purchase.error.title"),
                    message: String(localized: "support.purchase.unknown")
                )
            }
        } catch {
            notice = SupportPurchaseNotice(
                title: String(localized: "support.purchase.error.title"),
                message: String(localized: "support.purchase.failed")
            )
        }
    }

    private enum TransactionSource {
        case directPurchase
        case transactionUpdates
    }

    private func handleTransaction(
        _ result: VerificationResult<StoreKit.Transaction>,
        source: TransactionSource
    ) async {
        switch result {
        case .verified(let transaction):
            guard isSupportProduct(transaction.productID) else { return }
            let didRecord = recordSupportIfNeeded(transaction)
            await transaction.finish()

            if didRecord || source == .directPurchase {
                notice = SupportPurchaseNotice(
                    title: String(localized: "support.purchase.success.title"),
                    message: String(localized: "support.purchase.success.message")
                )
            }

        case .unverified:
            notice = SupportPurchaseNotice(
                title: String(localized: "support.purchase.error.title"),
                message: String(localized: "support.purchase.unverified")
            )
        }
    }

    private func recordSupportIfNeeded(_ transaction: StoreKit.Transaction) -> Bool {
        let transactionID = String(transaction.id)
        var processedIDs = userDefaults.stringArray(forKey: DefaultsKey.processedSupportTransactionIds) ?? []
        guard !processedIDs.contains(transactionID) else { return false }

        processedIDs.append(transactionID)
        if processedIDs.count > 50 {
            processedIDs.removeFirst(processedIDs.count - 50)
        }

        supportPurchaseCount += 1
        lastSupportProductId = transaction.productID
        lastSupportDate = transaction.purchaseDate

        userDefaults.set(processedIDs, forKey: DefaultsKey.processedSupportTransactionIds)
        userDefaults.set(supportPurchaseCount, forKey: DefaultsKey.supportPurchaseCount)
        userDefaults.set(lastSupportProductId, forKey: DefaultsKey.lastSupportProductId)
        userDefaults.set(lastSupportDate, forKey: DefaultsKey.lastSupportDate)

        return true
    }

    private func sortOrder(for productID: String) -> Int {
        SupportProduct(rawValue: productID)?.sortOrder ?? Int.max
    }

    private func isSupportProduct(_ productID: String) -> Bool {
        SupportProduct(rawValue: productID) != nil
    }
}
