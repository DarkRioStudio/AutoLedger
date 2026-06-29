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

@MainActor
final class ProEntitlementManager: ObservableObject {
    static let shared = ProEntitlementManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var loadState: ProEntitlementLoadState = .idle
    @Published private(set) var activeProductIDs: Set<String> = []
    @Published private(set) var lastVerifiedAt: Date?

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
                await self?.refreshEntitlements()
                if case .verified(let transaction) = verification,
                   Self.isProProductID(transaction.productID) {
                    await transaction.finish()
                }
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

    private var isDevelopmentOverrideEnabled: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "autoLedgerProDevelopmentOverride")
        #else
        false
        #endif
    }
}
