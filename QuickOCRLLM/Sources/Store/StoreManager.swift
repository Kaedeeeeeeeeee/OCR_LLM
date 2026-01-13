import Foundation
import Combine
import StoreKit

/// Product identifiers for the app
enum ProductID: String, CaseIterable {
    // Non-consumable: Base version unlock
    case base = "com.peek.base"
    
    // Auto-renewable subscription: Pro monthly
    case proMonthly = "com.peek.pro.monthly"
    
    // Consumables: Credit packs
    case credits200 = "com.peek.credits.200"
    case credits500 = "com.peek.credits.500"
    case credits1500 = "com.peek.credits.1500"
    
    var creditAmount: Int {
        switch self {
        case .credits200: return 200
        case .credits500: return 500
        case .credits1500: return 1500
        default: return 0
        }
    }
    
    static var allIdentifiers: Set<String> {
        Set(allCases.map { $0.rawValue })
    }
}

/// Manages StoreKit 2 products and purchases
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    
    private var updateTask: Task<Void, Never>?
    
    private init() {
        updateTask = Task {
            await listenForTransactions()
        }
    }
    
    deinit {
        updateTask?.cancel()
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await Product.products(for: ProductID.allIdentifiers)
                .sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            
            // Handle credit purchases
            if let productID = ProductID(rawValue: product.id),
               productID.creditAmount > 0 {
                CreditManager.shared.addPurchasedCredits(productID.creditAmount)
            }
            
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            return false
            
        @unknown default:
            return false
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        await updatePurchasedProducts()
    }
    
    // MARK: - Check Entitlements
    
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchased.insert(transaction.productID)
            }
        }
        
        purchasedProductIDs = purchased
        
        // Update entitlement manager
        EntitlementManager.shared.updateEntitlements(from: purchased)
    }
    
    // MARK: - Helpers
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await updatePurchasedProducts()
                await transaction.finish()
            }
        }
    }
    
    // MARK: - Product Helpers
    
    func product(for id: ProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }
    
    var baseProduct: Product? { product(for: .base) }
    var proMonthlyProduct: Product? { product(for: .proMonthly) }
}

enum StoreError: Error, LocalizedError {
    case verificationFailed
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed"
        }
    }
}
