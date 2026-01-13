import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var entitlementManager = EntitlementManager.shared
    @StateObject private var creditManager = CreditManager.shared
    
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current Status
                statusSection
                
                Divider()
                
                // Products
                if storeManager.isLoading {
                    ProgressView("Loading products...")
                } else {
                    productsSection
                }
                
                // Restore button
                Button("Restore Purchases") {
                    Task {
                        await storeManager.restorePurchases()
                    }
                }
                .buttonStyle(.link)
                .padding(.top)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 500)
        .task {
            await storeManager.loadProducts()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Status")
                .font(.headline)
            
            HStack {
                Image(systemName: entitlementManager.hasBaseAccess ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(entitlementManager.hasBaseAccess ? .green : .secondary)
                Text("Base Version")
                Spacer()
                Text(entitlementManager.hasBaseAccess ? "Purchased" : "Not Purchased")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: entitlementManager.hasProSubscription ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(entitlementManager.hasProSubscription ? .green : .secondary)
                Text("Pro Subscription")
                Spacer()
                Text(entitlementManager.hasProSubscription ? "Active" : "Not Active")
                    .foregroundColor(.secondary)
            }
            
            if entitlementManager.hasProSubscription {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                    Text("AI Credits")
                    Spacer()
                    Text("\(creditManager.totalCredits)")
                        .fontWeight(.semibold)
                        .foregroundColor(creditManager.hasCredits ? .primary : .red)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Products Section
    
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Base Version
            if !entitlementManager.hasBaseAccess {
                if let baseProduct = storeManager.baseProduct {
                    ProductCard(
                        title: "Base Version",
                        description: "Unlock Vision OCR - Local, fast, no network needed",
                        product: baseProduct,
                        isPurchasing: $isPurchasing
                    ) {
                        await purchase(baseProduct)
                    }
                }
            }
            
            // Pro Subscription
            if !entitlementManager.hasProSubscription {
                if let proProduct = storeManager.proMonthlyProduct {
                    ProductCard(
                        title: "Pro Monthly",
                        description: "AI OCR with 1000 credits/month",
                        product: proProduct,
                        isPurchasing: $isPurchasing
                    ) {
                        await purchase(proProduct)
                    }
                }
            }
            
            // Credit Packs (only show if Pro subscriber)
            if entitlementManager.hasProSubscription {
                Text("Credit Packs")
                    .font(.headline)
                    .padding(.top)
                
                ForEach(creditProducts, id: \.id) { product in
                    ProductCard(
                        title: creditPackTitle(for: product),
                        description: "Never expires",
                        product: product,
                        isPurchasing: $isPurchasing
                    ) {
                        await purchase(product)
                    }
                }
            }
        }
    }
    
    private var creditProducts: [Product] {
        storeManager.products.filter {
            $0.id.contains("credits")
        }
    }
    
    private func creditPackTitle(for product: Product) -> String {
        if let productID = ProductID(rawValue: product.id) {
            return "\(productID.creditAmount) Credits"
        }
        return product.displayName
    }
    
    private func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            _ = try await storeManager.purchase(product)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let title: String
    let description: String
    let product: Product
    @Binding var isPurchasing: Bool
    let action: () async -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                Task { await action() }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(product.displayPrice)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPurchasing)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
    }
}
