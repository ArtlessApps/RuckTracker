import Foundation
import StoreKit
import SwiftUI

@MainActor
class StoreKitManager: NSObject, ObservableObject {
    static let shared = StoreKitManager()
    
    // MARK: - Published Properties
    // MARK: - DEPRECATED: Subscription Support (Remove after migration)
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var availableSubscriptions: [Product] = []
    @Published var proUnlockProduct: Product?
    @Published var hasProUnlock: Bool = false
    @Published var isLoading = false
    @Published var purchaseError: PurchaseError?
    @Published var showingPurchaseError = false
    @Published var showingPostPurchasePrompt = false
    
    // Product IDs - these must match your App Store Connect configuration
    // MARK: - DEPRECATED: Subscription Support (Remove after migration)
    private let monthlySubscriptionID = "com.artless.rucktracker.premium.monthly"
    private let yearlySubscriptionID = "com.artless.rucktracker.premium.yearly"
    private let proUnlockID = "com.artless.rucktracker.pro.unlock"
    
    // Current subscription info
    @Published var currentSubscription: Product?
    @Published var subscriptionGroupStatus: Product.SubscriptionInfo.RenewalInfo?
    
    private var updateListenerTask: Task<Void, Error>?
    private var isCheckingStatus = false
    private var lastStatusCheck: Date = Date.distantPast
    
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
            await checkProUnlockStatus()  // Check for one-time purchase
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
            let products = try await Product.products(for: [
                monthlySubscriptionID,
                yearlySubscriptionID,
                proUnlockID  // ADD THIS
            ])
            
            DispatchQueue.main.async {
                self.availableSubscriptions = products.filter {
                    $0.type == .autoRenewable
                }.sorted { $0.price < $1.price }
                
                // ADD THIS:
                self.proUnlockProduct = products.first { 
                    $0.id == self.proUnlockID 
                }
            }
            print("✅ Loaded \(products.count) products")
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
                
                // Show post-purchase prompt for anonymous users
                await showPostPurchasePromptIfNeeded()
                
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
    
    // TODO: Remove subscription loading after migration complete
    // func checkSubscriptionStatus() async { ... }
    func checkSubscriptionStatus() async {
        // Prevent multiple simultaneous status checks
        guard !isCheckingStatus else { 
            print("🔄 Subscription status check already in progress, skipping...")
            return 
        }
        isCheckingStatus = true
        defer { isCheckingStatus = false }
        
        print("🔍 Checking subscription status...")
        // Don't set to loading to avoid triggering PremiumManager updates
        // subscriptionStatus = .loading
        
        do {
            for await result in StoreKit.Transaction.currentEntitlements {
                let transaction = try checkVerified(result)
                print("🔍 Found transaction: \(transaction.productID), type: \(transaction.productType), purchase date: \(transaction.purchaseDate)")
                
                if transaction.productID == monthlySubscriptionID || transaction.productID == yearlySubscriptionID {
                    print("🔍 Processing subscription transaction: \(transaction.productID)")
                    
                    // Check if this is a test transaction (sandbox environment)
                    #if DEBUG
                    if transaction.environment == .sandbox {
                        print("⚠️ Found sandbox/test subscription - this should not be active in production")
                        // In debug mode, we might want to ignore test subscriptions
                        // Uncomment the next line to ignore sandbox subscriptions in debug
                        // continue
                    }
                    #endif
                    
                    // Check if subscription is active
                    if let expirationDate = transaction.expirationDate {
                        print("🔍 Subscription expires: \(expirationDate), current date: \(Date())")
                        if expirationDate > Date() {
                            subscriptionStatus = .subscribed(expiry: expirationDate)
                            print("✅ Active subscription found - setting to subscribed")
                            
                            // Find the current product
                            currentSubscription = availableSubscriptions.first { $0.id == transaction.productID }
                        } else {
                            subscriptionStatus = .expired
                            print("❌ Subscription expired")
                        }
                    } else {
                        // Non-consumable or active subscription
                        subscriptionStatus = .subscribed(expiry: Date.distantFuture)
                        print("✅ Non-consumable subscription found - setting to subscribed")
                    }
                    
                    print("✅ Subscription status updated: \(subscriptionStatus)")
                    return
                } else {
                    print("🔍 Ignoring non-subscription transaction: \(transaction.productID)")
                }
            }
            
            // No active subscription found
            print("🔍 No subscription transactions found - setting to notSubscribed")
            subscriptionStatus = .notSubscribed
            
        } catch {
            print("❌ Failed to check subscription status: \(error)")
            subscriptionStatus = .notSubscribed
        }
    }
    
    private func checkProUnlockStatus() async {
        print("🔍 Checking Pro Unlock status...")
        // Check if user has purchased the one-time unlock
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.productID == proUnlockID {
                print("✅ Pro Unlock found! Setting hasProUnlock = true")
                DispatchQueue.main.async {
                    self.hasProUnlock = true
                }
                return
            }
        }
        
        print("❌ No Pro Unlock found - setting hasProUnlock = false")
        DispatchQueue.main.async {
            self.hasProUnlock = false
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
        // Debounce status checks to prevent rapid successive calls
        let now = Date()
        let timeSinceLastCheck = now.timeIntervalSince(lastStatusCheck)
        
        // Only check if it's been at least 1 second since last check
        guard timeSinceLastCheck >= 1.0 else {
            print("🔄 Debouncing subscription status check (last check was \(String(format: "%.1f", timeSinceLastCheck))s ago)")
            return
        }
        
        lastStatusCheck = now
        await checkSubscriptionStatus()
        await checkProUnlockStatus()  // ADD THIS LINE
        
        // Note: Removed notification posting since PremiumManager already listens to 
        // subscriptionStatus changes directly via @Published property
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
    
    // MARK: - Post-Purchase Prompt
    
    private func showPostPurchasePromptIfNeeded() async {
        // Check if user is anonymous (no email set)
        let userSettings = UserSettings.shared
        let isAnonymous = userSettings.email?.isEmpty != false
        
        if isAnonymous {
            // Add a small delay to ensure the paywall is fully dismissed first
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            DispatchQueue.main.async {
                self.showingPostPurchasePrompt = true
            }
        }
    }
    
    func dismissPostPurchasePrompt() {
        showingPostPurchasePrompt = false
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
        // User has premium if they have EITHER subscription OR one-time unlock
        let hasSubscription: Bool = {
            switch subscriptionStatus {
            case .subscribed, .inGracePeriod:
                return true
            case .loading, .notSubscribed, .expired:
                return false
            }
        }()
        
        return hasSubscription || hasProUnlock
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
