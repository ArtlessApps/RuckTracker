import Foundation
import StoreKit
import SwiftUI

@MainActor
class StoreKitManager: NSObject, ObservableObject {
    static let shared = StoreKitManager()
    
    // MARK: - Published Properties
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var availableSubscriptions: [Product] = []
    @Published var isLoading = false
    @Published var purchaseError: PurchaseError?
    @Published var showingPurchaseError = false
    
    // Product IDs - these must match your App Store Connect configuration
    private let monthlySubscriptionID = "com.artless.rucktracker.premium.monthly"
    private let yearlySubscriptionID = "com.artless.rucktracker.premium.yearly"
    
    // Current subscription info
    @Published var currentSubscription: Product?
    @Published var subscriptionGroupStatus: Product.SubscriptionInfo.RenewalInfo?
    
    private var updateListenerTask: Task<Void, Error>?
    
    enum SubscriptionStatus {
        case notSubscribed
        case subscribed(expiry: Date)
        case expired
        case inGracePeriod(expiry: Date)
        case loading
    }
    
    override init() {
        super.init()
        
        // Start listening for transaction updates
        updateListenerTask = listenForStoreKitTransactions()
        
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let products = try await Product.products(for: [monthlySubscriptionID, yearlySubscriptionID])
            self.availableSubscriptions = products.sorted { $0.price < $1.price }
            print("✅ Loaded \(products.count) subscription products")
        } catch {
            print("❌ Failed to load products: \(error)")
            handlePurchaseError(.productLoadFailed(error))
        }
    }
    
    // MARK: - Purchase Flow
    
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification) as StoreKit.Transaction
                
                // The transaction is verified. Deliver content to the user.
                await updateCustomerProductStatus()
                
                // Always finish a transaction.
                await transaction.finish()
                
                return transaction
                
            case .userCancelled:
                print("🚫 User cancelled purchase")
                return nil
                
            case .pending:
                print("⏳ Purchase pending approval")
                return nil
                
            @unknown default:
                return nil
            }
        } catch {
            print("❌ Purchase failed: \(error)")
            handlePurchaseError(.purchaseFailed(error))
            throw error
        }
    }
    
    // MARK: - Subscription Status
    
    func checkSubscriptionStatus() async {
        subscriptionStatus = .loading
        
        do {
            for await result in StoreKit.Transaction.currentEntitlements {
                let transaction = try checkVerified(result)
                if transaction.productID == monthlySubscriptionID || transaction.productID == yearlySubscriptionID {
            
                    // Check if subscription is active
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            subscriptionStatus = .subscribed(expiry: expirationDate)
                            
                            // Find the current product
                            currentSubscription = availableSubscriptions.first { $0.id == transaction.productID }
                        } else {
                            subscriptionStatus = .expired
                        }
                    } else {
                        // Non-consumable or active subscription
                        subscriptionStatus = .subscribed(expiry: Date.distantFuture)
                    }
                    
                    print("✅ Subscription status updated: \(subscriptionStatus)")
                    return
                }
            }
            
            // No active subscription found
            subscriptionStatus = .notSubscribed
            
        } catch {
            print("❌ Failed to check subscription status: \(error)")
            subscriptionStatus = .notSubscribed
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updateCustomerProductStatus()
            print("✅ Purchases restored")
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            handlePurchaseError(.restoreFailed(error))
        }
    }
    
    // MARK: - StoreKit Transaction Updates
    
    private func listenForStoreKitTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result) as StoreKit.Transaction
                    await self.updateCustomerProductStatus()
                    await transaction.finish()
                } catch {
                    print("❌ Transaction update failed: \(error)")
                }
            }
        }
    }
    
    private func updateCustomerProductStatus() async {
        await checkSubscriptionStatus()
        
        // Notify other parts of the app about subscription changes
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
    
    // MARK: - Verification
    
    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Error Handling
    
    private func handlePurchaseError(_ error: PurchaseError) {
        DispatchQueue.main.async {
            self.purchaseError = error
            self.showingPurchaseError = true
        }
    }
    
    // MARK: - Convenience Properties
    
    var isSubscribed: Bool {
        switch subscriptionStatus {
        case .subscribed, .inGracePeriod:
            return true
        default:
            return false
        }
    }
    
    var subscriptionExpiryDate: Date? {
        switch subscriptionStatus {
        case .subscribed(let expiry), .inGracePeriod(let expiry):
            return expiry
        default:
            return nil
        }
    }
    
    // Get the best deal for promotional purposes
    var recommendedSubscription: Product? {
        // Return yearly if available, otherwise monthly
        return availableSubscriptions.first { $0.id == yearlySubscriptionID } 
            ?? availableSubscriptions.first { $0.id == monthlySubscriptionID }
    }
    
    // Calculate savings for yearly vs monthly
    func yearlyDiscount() -> String? {
        guard let monthly = availableSubscriptions.first(where: { $0.id == monthlySubscriptionID }),
              let yearly = availableSubscriptions.first(where: { $0.id == yearlySubscriptionID }) else {
            return nil
        }
        
        let monthlyYearlyPrice = monthly.price * 12
        let savings = monthlyYearlyPrice - yearly.price
        let percentage = (savings / monthlyYearlyPrice) * 100
        
        return String(format: "%.0f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }
}

// MARK: - Supporting Types

enum PurchaseError: LocalizedError {
    case productLoadFailed(Error)
    case purchaseFailed(Error)
    case restoreFailed(Error)
    case subscriptionExpired
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .productLoadFailed:
            return "Failed to load subscription options. Please check your connection and try again."
        case .purchaseFailed:
            return "Purchase failed. Please try again or contact support if the problem persists."
        case .restoreFailed:
            return "Failed to restore purchases. Please try again."
        case .subscriptionExpired:
            return "Your subscription has expired. Please renew to continue accessing premium features."
        case .networkError:
            return "Network error. Please check your connection and try again."
        }
    }
}

enum StoreError: Error {
    case failedVerification
}

// MARK: - Extensions

extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}

extension StoreKitManager.SubscriptionStatus: Equatable {
    static func == (lhs: StoreKitManager.SubscriptionStatus, rhs: StoreKitManager.SubscriptionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notSubscribed, .notSubscribed), (.expired, .expired), (.loading, .loading):
            return true
        case (.subscribed(let lhsExpiry), .subscribed(let rhsExpiry)):
            return lhsExpiry == rhsExpiry
        case (.inGracePeriod(let lhsExpiry), .inGracePeriod(let rhsExpiry)):
            return lhsExpiry == rhsExpiry
        default:
            return false
        }
    }
}

// MARK: - Product Extensions for UI

extension Product {
    var localizedPrice: String {
        return price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
    
    var subscriptionPeriodDescription: String {
        guard let subscription = subscription else { return "" }
        
        let period = subscription.subscriptionPeriod
        let unit = period.unit
        let value = period.value
        
        switch unit {
        case .day:
            return value == 1 ? "Daily" : "\(value) days"
        case .week:
            return value == 1 ? "Weekly" : "\(value) weeks"
        case .month:
            return value == 1 ? "Monthly" : "\(value) months"
        case .year:
            return value == 1 ? "Yearly" : "\(value) years"
        @unknown default:
            return "Unknown"
        }
    }
    
    var isYearlySubscription: Bool {
        return subscription?.subscriptionPeriod.unit == .year
    }
    
    var isMonthlySubscription: Bool {
        return subscription?.subscriptionPeriod.unit == .month
    }
}
