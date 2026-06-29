import AutoLedgerCore
import Combine
import Foundation
import StoreKit

enum AutoLedgerProProduct: String, CaseIterable, Identifiable {
    case monthly = "top.darkrio326.AutoLedger.pro.monthly"
    case yearly = "top.darkrio326.AutoLedger.pro.yearly"

    var id: String { rawValue }
}

enum ProEntitlementLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

struct ProPurchaseNotice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class ProEntitlementManager: ObservableObject {
    static let shared = ProEntitlementManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var loadState: ProEntitlementLoadState = .idle
    @Published private(set) var purchasingProductID: String?
    @Published private(set) var activeProductIDs: Set<String> = []
    @Published private(set) var lastVerifiedAt: Date?
    @Published var notice: ProPurchaseNotice?

    private let policy: AutoLedgerProAccessPolicy
    private var transactionUpdatesTask: Task<Void, Never>?

    private init(policy: AutoLedgerProAccessPolicy = .current) {
        self.policy = policy
    }

    var isProActive: Bool {
        !activeProductIDs.isEmpty || isDevelopmentOverrideEnabled
    }

    func startTransactionListener() {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [weak self] in
            for await verification in StoreKit.Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.handleTransaction(verification, source: .transactionUpdates)
            }
        }

        Task {
            await refreshEntitlements()
        }
    }

    func loadProducts(forceRefresh: Bool = false) async {
        guard loadState != .loading else { return }
        if forceRefresh {
            products = []
        }

        loadState = .loading
        do {
            let fetchedProducts = try await Product.products(for: AutoLedgerProProduct.allCases.map(\.rawValue))
            products = fetchedProducts.sorted { lhs, rhs in
                productSortOrder(lhs.id) < productSortOrder(rhs.id)
            }
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func refreshEntitlements() async {
        var activeIDs: Set<String> = []
        for await verification in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification,
                  Self.isProProductID(transaction.productID),
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > Date() }) ?? true else {
                continue
            }
            activeIDs.insert(transaction.productID)
        }

        activeProductIDs = activeIDs
        lastVerifiedAt = Date()
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
                notice = ProPurchaseNotice(
                    title: String(localized: "pro.purchase.pending.title"),
                    message: String(localized: "pro.purchase.pending.message")
                )
            case .userCancelled:
                break
            @unknown default:
                notice = ProPurchaseNotice(
                    title: String(localized: "pro.purchase.error.title"),
                    message: String(localized: "pro.purchase.unknown")
                )
            }
        } catch {
            notice = ProPurchaseNotice(
                title: String(localized: "pro.purchase.error.title"),
                message: String(localized: "pro.purchase.failed")
            )
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            notice = isProActive
                ? ProPurchaseNotice(
                    title: String(localized: "pro.restore.success.title"),
                    message: String(localized: "pro.restore.success.message")
                )
                : ProPurchaseNotice(
                    title: String(localized: "pro.restore.empty.title"),
                    message: String(localized: "pro.restore.empty.message")
                )
        } catch {
            notice = ProPurchaseNotice(
                title: String(localized: "pro.purchase.error.title"),
                message: String(localized: "pro.restore.failed")
            )
        }
    }

    func canUse(_ capability: AutoLedgerCapability) -> Bool {
        if policy.isAvailableWithoutPro(capability) {
            return true
        }
        if policy.requiresActiveProInCurrentRelease(capability) {
            return isProActive
        }
        return false
    }

    func requiresPro(_ capability: AutoLedgerCapability) -> Bool {
        policy.requiresActiveProInCurrentRelease(capability)
    }

    private func productSortOrder(_ productID: String) -> Int {
        switch AutoLedgerProProduct(rawValue: productID) {
        case .monthly: return 0
        case .yearly: return 1
        case .none: return Int.max
        }
    }

    private static func isProProductID(_ productID: String) -> Bool {
        AutoLedgerProProduct(rawValue: productID) != nil
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
            guard Self.isProProductID(transaction.productID) else { return }
            await refreshEntitlements()
            await transaction.finish()

            if source == .directPurchase {
                notice = ProPurchaseNotice(
                    title: String(localized: "pro.purchase.success.title"),
                    message: String(localized: "pro.purchase.success.message")
                )
            }

        case .unverified:
            notice = ProPurchaseNotice(
                title: String(localized: "pro.purchase.error.title"),
                message: String(localized: "pro.purchase.unverified")
            )
        }
    }

    private var isDevelopmentOverrideEnabled: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "autoLedgerProDevelopmentOverride")
        #else
        false
        #endif
    }
}
