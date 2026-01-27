import Foundation
import SwiftUI
import Combine

/// PremiumManager handles premium subscription status
///
/// Key Design Principle:
/// Premium status is determined SOLELY by StoreKit subscription status
/// - Premium is tied to Apple ID, NOT user email/authentication
/// - Anonymous users CAN have premium (they purchased via Apple Pay)
/// - Premium persists across sign in/sign out (tied to device's Apple ID)
/// - Signing out does NOT affect premium status
@MainActor
class PremiumManager: ObservableObject {
    static let shared = PremiumManager()
    
    @Published var isPremiumUser = false
    @Published var subscriptionExpiryDate: Date?
    @Published var showingPaywall = false
    @Published var paywallContext: SubscriptionPaywallView.PaywallContext = .featureUpsell
    @Published var showingPostPurchasePrompt = false
    
    private let storeKitManager = StoreKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSubscriptions()
        updatePremiumStatus()
    }
    
    private func setupSubscriptions() {
        // Listen to subscription status changes with a small delay to ensure stability
        storeKitManager.$subscriptionStatus
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updatePremiumStatus()
            }
            .store(in: &cancellables)
        
        
        // Listen to post-purchase prompt from StoreKitManager
        storeKitManager.$showingPostPurchasePrompt
            .sink { [weak self] showing in
                self?.showingPostPurchasePrompt = showing
            }
            .store(in: &cancellables)
        
        // Note: Removed duplicate notification listener since we already listen to 
        // storeKitManager.$subscriptionStatus changes above
    }
    
    private func updatePremiumStatus() {
        let wasPremium = isPremiumUser
        let storeKitSubscribed = storeKitManager.isSubscribed
        let newExpiryDate = storeKitManager.subscriptionExpiryDate
        
        // Premium status is based on StoreKit subscription status
        // Users with valid subscriptions get premium access regardless of authentication status
        // This allows anonymous users who purchase subscriptions to access premium features
        let newPremiumStatus = storeKitSubscribed
        
        // Always update the status, even if it's the same
        isPremiumUser = newPremiumStatus
        subscriptionExpiryDate = newPremiumStatus ? newExpiryDate : nil
        
        // Log status changes with more detail
        if wasPremium != isPremiumUser {
            print("🔐 Premium status updated: \(isPremiumUser ? "Premium" : "Free")")
            print("🔐 StoreKit subscription: \(storeKitSubscribed)")
            print("🔐 User authenticated: true (local-only)")
            print("🔐 User has email: false (local-only)")
            print("🔐 StoreKit subscription status: \(storeKitManager.subscriptionStatus)")
            if let expiry = newExpiryDate {
                print("🔐 Subscription expiry: \(expiry)")
            }
        } else {
            // Log current status for debugging
            print("🔐 Premium status unchanged: \(isPremiumUser ? "Premium" : "Free")")
            print("🔐 StoreKit subscription: \(storeKitSubscribed)")
            print("🔐 User authenticated: true (local-only)")
            print("🔐 User has email: false (local-only)")
        }
    }
    
    // MARK: - Feature Gating
    
    func requiresPremium(for feature: PremiumFeature) -> Bool {
        return !isPremiumUser && feature.requiresPremium
    }
    
    func checkAccess(to feature: PremiumFeature, context: SubscriptionPaywallView.PaywallContext = .featureUpsell) -> Bool {
        if requiresPremium(for: feature) {
            showPaywall(context: context)
            return false
        }
        return true
    }
    
    func showPaywall(context: SubscriptionPaywallView.PaywallContext) {
        paywallContext = context
        showingPaywall = true
        print("🔐 Showing paywall")
    }
    
    func dismissPostPurchasePrompt() {
        showingPostPurchasePrompt = false
        storeKitManager.dismissPostPurchasePrompt()
    }
    
    func dismissPaywall() {
        showingPaywall = false
    }
    
    // MARK: - Sign Out Handling
    
    /// This method is intentionally a no-op
    /// Premium status is tied to Apple ID / StoreKit, not authentication state
    /// When a user signs out, they get a NEW anonymous session but keep their premium
    /// status if their device's Apple ID has an active subscription
    func resetPremiumStatusForSignOut() {
        print("🔐 Sign out detected - premium status remains unchanged")
        print("🔐 Premium is tied to Apple ID, not authentication")
        print("🔐 Current premium status: \(isPremiumUser ? "Premium" : "Free")")
        // Premium status remains tied to device's Apple ID subscription
        // No action needed
    }
    
    // MARK: - Free Trial Logic
    
    var isInFreeTrial: Bool {
        // This would be determined by StoreKit's subscription status
        // For now, simple check based on subscription status
        switch storeKitManager.subscriptionStatus {
        case .subscribed(let expiry):
            // If subscribed for less than 7 days, likely in trial
            let trialEnd = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
            return expiry > Date() && expiry > trialEnd
        default:
            return false
        }
    }
    
    var freeTrialDaysRemaining: Int? {
        guard isInFreeTrial, let expiryDate = subscriptionExpiryDate else { return nil }
        
        let remainingTime = expiryDate.timeIntervalSince(Date())
        let remainingDays = Int(ceil(remainingTime / (24 * 60 * 60)))
        
        return max(0, remainingDays)
    }
}

// MARK: - Premium Features Enum

enum PremiumFeature {
    case trainingPrograms
    case weeklyChallenges
    case achievementSystem
    case exportData  // Only if you built this
    
    var requiresPremium: Bool {
        switch self {
        case .trainingPrograms, .weeklyChallenges, .achievementSystem, .exportData:
            return true
        }
    }
    
    var displayName: String {
        switch self {
        case .trainingPrograms:
            return "Training Programs"
        case .weeklyChallenges:
            return "Weekly Challenges"
        case .achievementSystem:
            return "Achievement System"
        case .exportData:
            return "Export Data"
        }
    }
    
    var description: String {
        switch self {
        case .trainingPrograms:
            return "Access all 10 structured training programs (4-12 weeks)"
        case .weeklyChallenges:
            return "Access all 8 focused weekly challenges"
        case .achievementSystem:
            return "Unlock badges and track accomplishments"
        case .exportData:
            return "Export workout data to CSV"
        }
    }
    
    var iconName: String {
        switch self {
        case .trainingPrograms:
            return "figure.hiking"
        case .weeklyChallenges:
            return "trophy.fill"
        case .achievementSystem:
            return "star.fill"
        case .exportData:
            return "square.and.arrow.up"
        }
    }
}

// MARK: - Premium UI Modifiers

struct PremiumGate: ViewModifier {
    let feature: PremiumFeature
    let context: SubscriptionPaywallView.PaywallContext
    @StateObject private var premiumManager = PremiumManager.shared
    
    func body(content: Content) -> some View {
        content
            .disabled(premiumManager.requiresPremium(for: feature))
            .overlay(alignment: .center) {
                if premiumManager.requiresPremium(for: feature) {
                    PremiumOverlay(feature: feature) {
                        premiumManager.showPaywall(context: context)
                    }
                }
            }
    }
}

struct PremiumOverlay: View {
    let feature: PremiumFeature
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundColor(Color("PrimaryMain"))
                
                Text("Premium Feature")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Tap to upgrade")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("PrimaryMain"), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Premium Badge

struct PremiumBadge: View {
    let size: BadgeSize
    
    enum BadgeSize {
        case small, medium, large
        
        var fontSize: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .subheadline
            }
        }
        
        var padding: (horizontal: CGFloat, vertical: CGFloat) {
            switch self {
            case .small: return (4, 2)
            case .medium: return (6, 3)
            case .large: return (8, 4)
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(size.fontSize)
            Text("PRO")
                .font(size.fontSize)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, size.padding.horizontal)
        .padding(.vertical, size.padding.vertical)
        .background(
            LinearGradient(
                colors: [Color("PrimaryMain"), Color("PrimaryMedium")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(6)
    }
}

// MARK: - View Extensions

extension View {
    func premiumGated(
        for feature: PremiumFeature,
        context: SubscriptionPaywallView.PaywallContext = .featureUpsell
    ) -> some View {
        modifier(PremiumGate(feature: feature, context: context))
    }
    
    func showsPremiumBadge(_ show: Bool = true, size: PremiumBadge.BadgeSize = .medium) -> some View {
        overlay(alignment: .topTrailing) {
            if show {
                PremiumBadge(size: size)
                    .offset(x: 4, y: -4)
            }
        }
    }
}

// MARK: - Premium Status View

struct PremiumStatusView: View {
    @StateObject private var premiumManager = PremiumManager.shared
    @StateObject private var storeManager = StoreKitManager.shared
    
    var body: some View {
        Group {
            if premiumManager.isPremiumUser {
                activePremiumView
            } else {
                upgradeToPremiumView
            }
        }
        .sheet(isPresented: $premiumManager.showingPaywall) {
            SubscriptionPaywallView(context: premiumManager.paywallContext)
        }
    }
    
    @ViewBuilder
    private var activePremiumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PremiumBadge(size: .medium)
                Spacer()
                if let expiryDate = premiumManager.subscriptionExpiryDate,
                   expiryDate != Date.distantFuture {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Expires")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(expiryDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            
            Text("You have access to all premium features")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if premiumManager.isInFreeTrial {
                if let daysRemaining = premiumManager.freeTrialDaysRemaining {
                    Text("\(daysRemaining) days left in free trial")
                        .font(.caption)
                        .foregroundColor(Color("PrimaryMain"))
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var upgradeToPremiumView: some View {
        Button {
            premiumManager.showPaywall(context: .settings)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(Color("PrimaryMain"))
                        Text("Upgrade to MARCH Pro")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Unlock training programs, analytics, and more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("PrimaryMain").opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("PrimaryMain").opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

