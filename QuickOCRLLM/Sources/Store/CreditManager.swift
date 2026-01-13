import Foundation
import Combine

/// Manages AI OCR credits
@MainActor
final class CreditManager: ObservableObject {
    static let shared = CreditManager()
    
    private let defaults = UserDefaults.standard
    private let subscriptionCreditsKey = "credits.subscription"
    private let purchasedCreditsKey = "credits.purchased"
    private let lastResetDateKey = "credits.lastResetDate"
    
    /// Monthly credits included with Pro subscription
    static let monthlySubscriptionCredits = 1000
    
    @Published private(set) var subscriptionCredits: Int = 0
    @Published private(set) var purchasedCredits: Int = 0
    
    var totalCredits: Int {
        subscriptionCredits + purchasedCredits
    }
    
    var hasCredits: Bool {
        totalCredits > 0
    }
    
    private init() {
        loadCredits()
    }
    
    // MARK: - Credit Operations
    
    /// Consume 1 credit for an AI OCR call
    /// Returns true if credit was consumed, false if no credits available
    func consumeCredit() -> Bool {
        guard hasCredits else { return false }
        
        // Priority: subscription credits first (they expire)
        if subscriptionCredits > 0 {
            subscriptionCredits -= 1
        } else {
            purchasedCredits -= 1
        }
        
        saveCredits()
        return true
    }
    
    /// Add purchased credits (permanent, never expire)
    func addPurchasedCredits(_ amount: Int) {
        purchasedCredits += amount
        saveCredits()
    }
    
    /// Reset subscription credits if a new billing period started
    func resetSubscriptionCreditsIfNeeded() {
        let calendar = Calendar.current
        let lastReset = defaults.object(forKey: lastResetDateKey) as? Date ?? .distantPast
        
        // Check if we're in a new month
        if !calendar.isDate(lastReset, equalTo: Date(), toGranularity: .month) {
            subscriptionCredits = Self.monthlySubscriptionCredits
            defaults.set(Date(), forKey: lastResetDateKey)
            saveCredits()
        }
    }
    
    /// Force reset subscription credits (for new subscribers)
    func grantSubscriptionCredits() {
        subscriptionCredits = Self.monthlySubscriptionCredits
        defaults.set(Date(), forKey: lastResetDateKey)
        saveCredits()
    }
    
    // MARK: - Persistence
    
    private func loadCredits() {
        subscriptionCredits = defaults.integer(forKey: subscriptionCreditsKey)
        purchasedCredits = defaults.integer(forKey: purchasedCreditsKey)
    }
    
    private func saveCredits() {
        defaults.set(subscriptionCredits, forKey: subscriptionCreditsKey)
        defaults.set(purchasedCredits, forKey: purchasedCreditsKey)
    }
}
