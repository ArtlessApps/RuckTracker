import Foundation
import StoreKit
import SwiftUI

@MainActor
class StoreKitManager: NSObject, ObservableObject {
    static let shared = StoreKitManager()
    
    // MARK: - Published Properties
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var isInIntroductoryOffer: Bool = false
    @Published var availableSubscriptions: [Product] = []
    @Published var isLoading = false
    @Published var purchaseError: PurchaseError?
    @Published var showingPurchaseError = false
    @Published var showingPostPurchasePrompt = false
    
    // Product IDs - these must match your App Store Connect configuration
    private let monthlySubscriptionID = "com.artless.rucktracker.premium.monthly"
    private let yearlySubscriptionID = "com.artless.rucktracker.premium.yearly"
    
    // Current subscription info
    @Published var currentSubscription: Product?
    @Published var subscriptionGroupStatus: Product.SubscriptionInfo.RenewalInfo?
    
    private var updateListenerTask: Task<Void, Error>?
    private var isCheckingStatus = false
    private var lastStatusCheck: Date = Date.distantPast
    /// After `finish()`, `currentEntitlements` can be momentarily empty on device; avoid clearing a subscription we just applied.
    private var subscriptionStateGraceUntil: Date = .distantPast
    
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
            let products = try await Product.products(for: [
                monthlySubscriptionID,
                yearlySubscriptionID
            ])
            
            // Synchronous assignment so await loadProducts() callers see products immediately.
            availableSubscriptions = products.filter {
                $0.type == .autoRenewable
            }.sorted { $0.price < $1.price }
            print("🛒 Loaded \(availableSubscriptions.count) subscriptions")
        } catch {
            print("🛒 ❌ Failed to load products: \(error)")
            handlePurchaseError(.productLoadFailed(error))
        }
    }
    
    // MARK: - Purchase Flow
    
    /// Purchase a product, optionally tagging it with the current user's UUID via appAccountToken.
    /// When `appAccountToken` is provided, the transaction is permanently linked to that user account
    /// in Apple's system, enabling per-user subscription verification on sign-in.
    func purchase(_ product: Product, appAccountToken: UUID? = nil) async throws -> StoreKit.Transaction? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            var options: Set<Product.PurchaseOption> = []
            if let token = appAccountToken {
                options.insert(.appAccountToken(token))
                print("🛒 Purchase tagged with appAccountToken: \(token)")
            }
            
            let result = try await product.purchase(options: options)
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification) as StoreKit.Transaction
                
                applyVerifiedSubscriptionTransaction(transaction)
                await transaction.finish()
                
                await showPostPurchasePromptIfNeeded()
                
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 750_000_000)
                    await self.updateCustomerProductStatus(bypassDebounce: true)
                }
                
                return transaction
                
            case .userCancelled:
                print("🛒 User cancelled purchase")
                return nil
                
            case .pending:
                print("🛒 Purchase pending approval")
                return nil
                
            @unknown default:
                return nil
            }
        } catch {
            print("🛒 ❌ Purchase failed: \(error)")
            handlePurchaseError(.purchaseFailed(error))
            throw error
        }
    }
    
    // MARK: - Per-User Entitlement Check
    
    /// Check if there's an active subscription entitlement tagged with the given user UUID.
    /// Returns the matching transaction if found. This is the per-user subscription check
    /// that prevents one user's subscription from leaking to another user on the same device.
    func activeEntitlement(for userId: UUID) async -> StoreKit.Transaction? {
        do {
            for await result in StoreKit.Transaction.currentEntitlements {
                let transaction = try checkVerified(result)
                
                guard transaction.productID == monthlySubscriptionID || transaction.productID == yearlySubscriptionID else {
                    continue
                }
                guard transaction.appAccountToken == userId else {
                    continue
                }
                
                if let expirationDate = transaction.expirationDate, expirationDate > Date() {
                    return transaction
                } else if transaction.expirationDate == nil {
                    return transaction
                }
            }
        } catch {
            print("🛒 ❌ Failed to check entitlements for user \(userId): \(error)")
        }
        return nil
    }
    
    // MARK: - Subscription Status
    
    func checkSubscriptionStatus() async {
        guard !isCheckingStatus else { return }
        isCheckingStatus = true
        defer { isCheckingStatus = false }
        // Don't set to loading to avoid triggering PremiumManager updates
        // subscriptionStatus = .loading
        
        do {
            for await result in StoreKit.Transaction.currentEntitlements {
                let transaction = try checkVerified(result)
                
                if transaction.productID == monthlySubscriptionID || transaction.productID == yearlySubscriptionID {
                    if let expirationDate = transaction.expirationDate {
                        if expirationDate > Date() {
                            applyActiveSubscription(from: transaction, expiry: expirationDate)
                        } else {
                            clearSubscriptionState()
                            subscriptionStatus = .expired
                        }
                    } else {
                        applyActiveSubscription(from: transaction, expiry: Date.distantFuture)
                    }
                    return
                }
            }
            
            if Date() < subscriptionStateGraceUntil {
                // Entitlements can lag briefly after finish(); keep the state we applied.
            } else {
                clearSubscriptionState()
                subscriptionStatus = .notSubscribed
            }
        } catch {
            print("🛒 ❌ Failed to check subscription status: \(error)")
            clearSubscriptionState()
            subscriptionStatus = .notSubscribed
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updateCustomerProductStatus(bypassDebounce: true)
        } catch {
            print("🛒 ❌ Failed to restore purchases: \(error)")
            handlePurchaseError(.restoreFailed(error))
        }
    }
    
    // MARK: - StoreKit Transaction Updates
    
    private func listenForStoreKitTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result) as StoreKit.Transaction
                    await self.updateCustomerProductStatus(bypassDebounce: true)
                    await transaction.finish()
                } catch {
                    print("🛒 ❌ Transaction update failed: \(error)")
                }
            }
        }
    }
    
    /// Updates `subscriptionStatus` from a verified transaction without waiting on
    /// `Transaction.currentEntitlements` (avoids production timing races after `purchase()`).
    private func applyVerifiedSubscriptionTransaction(_ transaction: StoreKit.Transaction) {
        guard transaction.productID == monthlySubscriptionID || transaction.productID == yearlySubscriptionID else {
            return
        }
        if transaction.revocationDate != nil {
            clearSubscriptionState()
            subscriptionStatus = .notSubscribed
            return
        }
        if let expirationDate = transaction.expirationDate {
            if expirationDate > Date() {
                applyActiveSubscription(from: transaction, expiry: expirationDate)
                subscriptionStateGraceUntil = Date().addingTimeInterval(20)
            } else {
                clearSubscriptionState()
                subscriptionStatus = .expired
            }
        } else {
            applyActiveSubscription(from: transaction, expiry: .distantFuture)
            subscriptionStateGraceUntil = Date().addingTimeInterval(20)
        }
    }
    
    private func applyActiveSubscription(from transaction: StoreKit.Transaction, expiry: Date) {
        subscriptionStatus = .subscribed(expiry: expiry)
        currentSubscription = availableSubscriptions.first { $0.id == transaction.productID }
        isInIntroductoryOffer = transaction.offerType == .introductory
    }
    
    private func clearSubscriptionState() {
        currentSubscription = nil
        isInIntroductoryOffer = false
    }
    
    /// - Parameter bypassDebounce: Use after purchase, restore, or `Transaction.updates` so we never
    ///   drop a refresh when checkout completes within the debounce window (common on device).
    private func updateCustomerProductStatus(bypassDebounce: Bool = false) async {
        if !bypassDebounce {
            let timeSinceLastCheck = Date().timeIntervalSince(lastStatusCheck)
            guard timeSinceLastCheck >= 1.0 else { return }
        }
        
        lastStatusCheck = Date()
        await checkSubscriptionStatus()
        
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
        switch subscriptionStatus {
        case .subscribed, .inGracePeriod:
            return true
        case .loading, .notSubscribed, .expired:
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
