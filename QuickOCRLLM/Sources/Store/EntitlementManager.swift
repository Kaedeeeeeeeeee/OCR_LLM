import Foundation
import Combine

/// Manages user entitlements (what features they have access to)
@MainActor
final class EntitlementManager: ObservableObject {
    static let shared = EntitlementManager()
    
    @Published private(set) var hasBaseAccess = false
    @Published private(set) var hasProSubscription = false
    
    private init() {
        // Load cached entitlements on init
        loadCachedEntitlements()
    }
    
    // MARK: - Entitlement Checks
    
    /// Can use Vision OCR (requires base purchase)
    var canUseVisionOCR: Bool {
        hasBaseAccess || hasProSubscription
    }
    
    /// Can use AI OCR (requires Pro subscription + credits)
    var canUseAIOCR: Bool {
        hasProSubscription && CreditManager.shared.hasCredits
    }
    
    // MARK: - Update from StoreKit
    
    func updateEntitlements(from purchasedIDs: Set<String>) {
        hasBaseAccess = purchasedIDs.contains(ProductID.base.rawValue)
        hasProSubscription = purchasedIDs.contains(ProductID.proMonthly.rawValue)
        
        // Reset subscription credits if Pro subscription is active
        if hasProSubscription {
            CreditManager.shared.resetSubscriptionCreditsIfNeeded()
        }
        
        // Cache entitlements
        cacheEntitlements()
    }
    
    // MARK: - Persistence
    
    private let defaults = UserDefaults.standard
    private let hasBaseKey = "entitlement.hasBase"
    private let hasProKey = "entitlement.hasPro"
    
    private func cacheEntitlements() {
        defaults.set(hasBaseAccess, forKey: hasBaseKey)
        defaults.set(hasProSubscription, forKey: hasProKey)
    }
    
    private func loadCachedEntitlements() {
        hasBaseAccess = defaults.bool(forKey: hasBaseKey)
        hasProSubscription = defaults.bool(forKey: hasProKey)
    }
}
