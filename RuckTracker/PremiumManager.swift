import Foundation
import SwiftUI
import StoreKit
import Combine

/// PremiumManager handles premium subscription status using `user_subscriptions` as the
/// per-user source of truth, with StoreKit `appAccountToken` linking purchases to users.
///
/// Key Design Principles:
/// - **Authenticated users**: Premium determined by their `user_subscriptions` record in the database
///   OR Ambassador status (club founder with 5+ members). StoreKit purchases are tagged with the
///   user's UUID via `appAccountToken` so they can be verified on sign-in.
/// - **Anonymous users**: Premium comes directly from StoreKit (tied to Apple ID / device).
///   Once they sign in, their entitlement is matched via `appAccountToken`.
/// - **Single source of truth**: The `user_subscriptions` table tracks who has a subscription,
///   when it expires, and the Apple transaction ID for auditability.
@MainActor
class PremiumManager: ObservableObject {
    static let shared = PremiumManager()
    
    @Published var isPremiumUser = false
    @Published var isAmbassador = false  // Club founder with 5+ members
    @Published var subscriptionExpiryDate: Date?
    @Published var showingPaywall = false
    @Published var paywallContext: SubscriptionPaywallView.PaywallContext = .featureUpsell
    @Published var showingPostPurchasePrompt = false
    
    /// Premium source for display purposes
    enum PremiumSource {
        case subscription
        case ambassador
        case none
    }
    @Published var premiumSource: PremiumSource = .none
    
    /// Whether the current authenticated user has an active subscription in the database.
    /// Loaded from `user_subscriptions` on sign-in; set on purchase; cleared on sign-out.
    private(set) var hasActiveSubscription = false
    
    private let storeKitManager = StoreKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSubscriptions()
        updatePremiumStatus()
    }
    
    private func setupSubscriptions() {
        // Listen to subscription status changes (for anonymous users and expiry detection)
        storeKitManager.$subscriptionStatus
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleSubscriptionStatusChange()
            }
            .store(in: &cancellables)
        
        // Listen to post-purchase prompt from StoreKitManager
        storeKitManager.$showingPostPurchasePrompt
            .sink { [weak self] showing in
                self?.showingPostPurchasePrompt = showing
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Premium Status Calculation
    
    /// Recalculate `isPremiumUser` based on the current state.
    /// - Authenticated: `hasActiveSubscription` (from DB) OR `isAmbassador`
    /// - Anonymous: StoreKit device-level subscription
    private func updatePremiumStatus() {
        let wasPremium = isPremiumUser
        let communityService = CommunityService.shared
        
        let newPremiumStatus: Bool
        
        if communityService.isAuthenticated {
            // Per-user: database subscription record + ambassador
            newPremiumStatus = hasActiveSubscription || isAmbassador
        } else {
            // Device-level: StoreKit entitlement
            newPremiumStatus = storeKitManager.isSubscribed
        }
        
        isPremiumUser = newPremiumStatus
        
        // Expiry date
        if hasActiveSubscription {
            subscriptionExpiryDate = storeKitManager.subscriptionExpiryDate
        } else if !communityService.isAuthenticated && storeKitManager.isSubscribed {
            subscriptionExpiryDate = storeKitManager.subscriptionExpiryDate
        } else {
            subscriptionExpiryDate = nil
        }
        
        // Premium source
        if hasActiveSubscription || (!communityService.isAuthenticated && storeKitManager.isSubscribed) {
            premiumSource = .subscription
        } else if isAmbassador {
            premiumSource = .ambassador
        } else {
            premiumSource = .none
        }
        
        if wasPremium != isPremiumUser {
            print("🔐 Premium status changed: \(isPremiumUser ? "Premium" : "Free")")
            print("🔐   Authenticated: \(communityService.isAuthenticated)")
            print("🔐   DB subscription: \(hasActiveSubscription)")
            print("🔐   Ambassador: \(isAmbassador)")
            print("🔐   StoreKit subscribed: \(storeKitManager.isSubscribed)")
            print("🔐   Source: \(premiumSource)")
        }
    }
    
    /// Handle StoreKit subscription status changes (expiry detection + anonymous updates).
    private func handleSubscriptionStatusChange() {
        let communityService = CommunityService.shared
        
        if communityService.isAuthenticated && hasActiveSubscription && premiumSource == .subscription {
            // Detect subscription expiry for authenticated user
            if !storeKitManager.isSubscribed {
                print("🔐 StoreKit reports expired - checking user's entitlement")
                Task {
                    await verifyAndSyncSubscription()
                }
            }
        }
        
        // Always recalculate (important for anonymous users)
        updatePremiumStatus()
    }
    
    // MARK: - Purchase Handling
    
    /// Record a successful purchase: write to `user_subscriptions` + update profile.
    /// Called from the paywall after `StoreKitManager.purchase()` returns a transaction.
    func handleSuccessfulPurchase(transaction: StoreKit.Transaction) {
        let communityService = CommunityService.shared
        
        guard communityService.isAuthenticated else {
            // Anonymous user - StoreKit handles it at device level
            print("🔐 Purchase by anonymous user - StoreKit provides device-level premium")
            updatePremiumStatus()
            return
        }
        
        // Determine subscription type from product ID
        let subType = transaction.productID.contains("yearly") ? "yearly" : "monthly"
        let transactionId = String(transaction.id)
        
        // Set local state immediately for responsive UI
        hasActiveSubscription = true
        updatePremiumStatus()
        
        // Write to database in background
        Task {
            do {
                try await communityService.recordSubscription(
                    type: subType,
                    appleTransactionId: transactionId,
                    expiresAt: transaction.expirationDate
                )
                print("🔐 Subscription recorded in database: \(subType) (tx: \(transactionId))")
            } catch {
                print("❌ Failed to record subscription in database: \(error)")
                // Local state is already set - will be synced on next sign-in
            }
        }
    }
    
    // MARK: - Sign In: Load & Verify Subscription
    
    /// Called after sign-in or session restore. Loads the user's subscription from the database,
    /// then verifies it against StoreKit entitlements tagged with their UUID.
    func evaluatePremiumForNewUser() {
        // Reset all user-level state
        hasActiveSubscription = false
        isAmbassador = false
        updatePremiumStatus()
        
        // Load subscription + ambassador status asynchronously
        Task {
            await loadSubscriptionForCurrentUser()
            await checkAmbassadorStatus()
        }
    }
    
    /// Load and verify the subscription for the current authenticated user.
    private func loadSubscriptionForCurrentUser() async {
        let communityService = CommunityService.shared
        
        guard let userId = communityService.currentProfile?.id else {
            print("🔐 No profile - skipping subscription load")
            return
        }
        
        do {
            // 1. Check the database for an active subscription record
            let dbSubscription = try await communityService.getActiveSubscription()
            
            // 2. Verify against StoreKit: does this user have a tagged entitlement?
            let storeKitEntitlement = await storeKitManager.activeEntitlement(for: userId)
            
            if dbSubscription != nil {
                if storeKitEntitlement != nil {
                    // DB says active, StoreKit confirms - all good
                    hasActiveSubscription = true
                    print("🔐 Subscription verified: DB ✓ StoreKit ✓")
                } else {
                    // DB says active but StoreKit doesn't confirm on this device.
                    // Could be: purchased on another device, or expired.
                    // Trust the DB (it's the cross-device source of truth).
                    hasActiveSubscription = true
                    print("🔐 Subscription from DB (not verified on this device - may be from another device)")
                }
            } else if let entitlement = storeKitEntitlement {
                // StoreKit has an entitlement for this user but DB doesn't know about it.
                // This can happen if the DB write failed on purchase. Reconcile it now.
                hasActiveSubscription = true
                let subType = entitlement.productID.contains("yearly") ? "yearly" : "monthly"
                try await communityService.recordSubscription(
                    type: subType,
                    appleTransactionId: String(entitlement.id),
                    expiresAt: entitlement.expirationDate
                )
                print("🔐 Reconciled: StoreKit entitlement written to DB")
            } else {
                // No subscription anywhere
                hasActiveSubscription = false
                print("🔐 No active subscription for user \(userId)")
            }
            
            updatePremiumStatus()
            
        } catch {
            print("❌ Failed to load subscription: \(error)")
            // Fall back to profile is_premium as last resort
            hasActiveSubscription = communityService.currentProfile?.isPremium ?? false
            updatePremiumStatus()
        }
    }
    
    /// Verify the current user's subscription against StoreKit and expire if needed.
    private func verifyAndSyncSubscription() async {
        let communityService = CommunityService.shared
        
        guard let userId = communityService.currentProfile?.id else { return }
        
        let entitlement = await storeKitManager.activeEntitlement(for: userId)
        
        if entitlement == nil && hasActiveSubscription && premiumSource == .subscription {
            // Subscription expired on this device
            hasActiveSubscription = false
            updatePremiumStatus()
            
            do {
                try await communityService.expireSubscription()
                print("🔐 Subscription expired and synced to database")
            } catch {
                print("❌ Failed to expire subscription in database: \(error)")
            }
        }
    }
    
    // MARK: - Ambassador System
    
    /// Check if user qualifies for Ambassador (free Pro) status.
    /// Club Founders with 5+ members get Pro for free.
    func checkAmbassadorStatus() async {
        let communityService = CommunityService.shared
        
        guard communityService.currentProfile != nil else {
            isAmbassador = false
            updatePremiumStatus()
            return
        }
        
        do {
            try await communityService.loadMyClubs()
            
            var qualifiesAsAmbassador = false
            for club in communityService.myClubs {
                let role = try await communityService.getUserRole(clubId: club.id)
                if role == .founder && club.memberCount >= 5 {
                    qualifiesAsAmbassador = true
                    break
                }
            }
            
            let wasAmbassador = isAmbassador
            isAmbassador = qualifiesAsAmbassador
            
            if wasAmbassador != isAmbassador {
                print("🎖️ Ambassador status changed: \(isAmbassador ? "Granted" : "Revoked")")
                updatePremiumStatus()
                
                // Sync ambassador status to profile and user_subscriptions
                if isAmbassador {
                    Task {
                        try? await communityService.recordSubscription(
                            type: "ambassador",
                            appleTransactionId: "ambassador",
                            expiresAt: nil
                        )
                    }
                }
            }
        } catch {
            print("❌ Failed to check ambassador status: \(error)")
            isAmbassador = false
            updatePremiumStatus()
        }
    }
    
    /// Refresh ambassador status when club membership changes
    func refreshAmbassadorStatus() {
        Task {
            await checkAmbassadorStatus()
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
    
    // MARK: - Sign Out
    
    /// Reset all user-level premium state on sign out.
    func resetPremiumStatusForSignOut() {
        print("🔐 Sign out - resetting all user-level premium state")
        hasActiveSubscription = false
        isAmbassador = false
        updatePremiumStatus()
        print("🔐 After sign-out: \(isPremiumUser ? "Premium (anonymous StoreKit)" : "Free")")
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
    // Core Training (Pro)
    case trainingPrograms       // Structured programs (4-12 weeks)
    case weeklyChallenges       // Weekly challenges
    case planExecution          // Starting/executing workouts from plans
    
    // Smart Coaching (Pro) — ⚠️ FUTURE FEATURES: Not yet implemented. See docs/FUTURE_FEATURES.md
    case audioCoaching          // Audio cues during workouts — NOT WIRED UP
    case heartRateZones         // Heart rate zone tracking — NOT WIRED UP
    case intervalTimers         // Smart interval timers — NOT WIRED UP
    
    // Analytics (Pro)
    case advancedAnalytics      // Tonnage trends, progress charts
    case achievementSystem      // Badges and accomplishments
    case exportData             // Export workout data to CSV
    
    // Competition (Pro)
    case globalLeaderboards     // Global rankings (vs local club only)
    case proBadges              // Exclusive Pro badges
    
    // Social/Sharing (Pro)
    case propagandaMode         // Enhanced share cards (tonnage, club badge, stencil theme)
    
    // Free Features (always available)
    case basicTracking          // Open Ruck GPS tracking
    case clubAccess             // Join clubs, RSVP, waivers, chat
    case localLeaderboards      // Club leaderboards
    case standardShareCard      // Basic share card
    
    var requiresPremium: Bool {
        switch self {
        // Pro features
        case .trainingPrograms, .weeklyChallenges, .planExecution,
             .audioCoaching, .heartRateZones, .intervalTimers,
             .advancedAnalytics, .achievementSystem, .exportData,
             .globalLeaderboards, .proBadges, .propagandaMode:
            return true
            
        // Free features
        case .basicTracking, .clubAccess, .localLeaderboards, .standardShareCard:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .trainingPrograms:
            return "Training Programs"
        case .weeklyChallenges:
            return "Weekly Challenges"
        case .planExecution:
            return "Plan Execution"
        case .audioCoaching:
            return "Smart Coaching"
        case .heartRateZones:
            return "Heart Rate Zones"
        case .intervalTimers:
            return "Interval Timers"
        case .advancedAnalytics:
            return "Advanced Analytics"
        case .achievementSystem:
            return "Achievement System"
        case .exportData:
            return "Export Data"
        case .globalLeaderboards:
            return "Global Leaderboards"
        case .proBadges:
            return "Pro Badges"
        case .propagandaMode:
            return "Propaganda Mode"
        case .basicTracking:
            return "Basic Tracking"
        case .clubAccess:
            return "Club Access"
        case .localLeaderboards:
            return "Club Leaderboards"
        case .standardShareCard:
            return "Share Card"
        }
    }
    
    var description: String {
        switch self {
        case .trainingPrograms:
            return "Access all 10+ structured training programs (4-12 weeks)"
        case .weeklyChallenges:
            return "Access all focused weekly challenges"
        case .planExecution:
            return "Execute workouts from your custom training plan"
        case .audioCoaching:
            return "Audio cues like 'Speed up', 'Halfway there', and pace guidance"
        case .heartRateZones:
            return "Track heart rate zones for optimal training"
        case .intervalTimers:
            return "Smart interval timers for structured workouts"
        case .advancedAnalytics:
            return "Tonnage trends, vertical gain analysis, progress charts over time"
        case .achievementSystem:
            return "Unlock badges and track accomplishments"
        case .exportData:
            return "Export workout data to CSV"
        case .globalLeaderboards:
            return "Rank against ruckers worldwide, not just your club"
        case .proBadges:
            return "Exclusive Pro badges to show off your status"
        case .propagandaMode:
            return "Massive tonnage overlay, club badge, military-stencil share cards"
        case .basicTracking:
            return "GPS tracking for distance, time, and pace"
        case .clubAccess:
            return "Join clubs, sign waivers, RSVP to events, group chat"
        case .localLeaderboards:
            return "View your club's weekly leaderboard"
        case .standardShareCard:
            return "Basic share card with workout stats"
        }
    }
    
    var iconName: String {
        switch self {
        case .trainingPrograms:
            return "figure.hiking"
        case .weeklyChallenges:
            return "trophy.fill"
        case .planExecution:
            return "play.circle.fill"
        case .audioCoaching:
            return "waveform.circle.fill"
        case .heartRateZones:
            return "heart.fill"
        case .intervalTimers:
            return "timer"
        case .advancedAnalytics:
            return "chart.xyaxis.line"
        case .achievementSystem:
            return "star.fill"
        case .exportData:
            return "square.and.arrow.up"
        case .globalLeaderboards:
            return "globe"
        case .proBadges:
            return "crown.fill"
        case .propagandaMode:
            return "photo.artframe"
        case .basicTracking:
            return "location.fill"
        case .clubAccess:
            return "person.3.fill"
        case .localLeaderboards:
            return "list.number"
        case .standardShareCard:
            return "square.and.arrow.up"
        }
    }
    
    /// Category for grouping in UI
    var category: FeatureCategory {
        switch self {
        case .trainingPrograms, .weeklyChallenges, .planExecution:
            return .training
        case .audioCoaching, .heartRateZones, .intervalTimers:
            return .coaching
        case .advancedAnalytics, .achievementSystem, .exportData:
            return .analytics
        case .globalLeaderboards, .proBadges:
            return .competition
        case .propagandaMode, .standardShareCard:
            return .sharing
        case .basicTracking, .clubAccess, .localLeaderboards:
            return .free
        }
    }
    
    enum FeatureCategory: String, CaseIterable {
        case training = "Training Plans"
        case coaching = "Smart Coaching"
        case analytics = "Analytics"
        case competition = "Competition"
        case sharing = "Social Sharing"
        case free = "Free Features"
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
                colors: [AppColors.primary, AppColors.accentTeal],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(6)
    }
}

// MARK: - Ambassador Badge

struct AmbassadorBadge: View {
    let size: PremiumBadge.BadgeSize
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.circle.fill")
                .font(size.fontSize)
            Text("AMBASSADOR")
                .font(size.fontSize)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, size.padding.horizontal)
        .padding(.vertical, size.padding.vertical)
        .background(
            LinearGradient(
                colors: [Color.orange, Color.yellow],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(6)
    }
}

// MARK: - Smart Premium Badge (shows correct badge based on source)

struct SmartPremiumBadge: View {
    @StateObject private var premiumManager = PremiumManager.shared
    let size: PremiumBadge.BadgeSize
    
    var body: some View {
        Group {
            switch premiumManager.premiumSource {
            case .ambassador:
                AmbassadorBadge(size: size)
            case .subscription:
                PremiumBadge(size: size)
            case .none:
                EmptyView()
            }
        }
    }
}

// MARK: - Tier Badge (Free vs Pro indicator)

struct TierBadge: View {
    let isPro: Bool
    let size: PremiumBadge.BadgeSize
    
    var body: some View {
        HStack(spacing: 4) {
            if isPro {
                Image(systemName: "crown.fill")
                    .font(size.fontSize)
                Text("PRO")
                    .font(size.fontSize)
                    .fontWeight(.semibold)
            } else {
                Image(systemName: "person.fill")
                    .font(size.fontSize)
                Text("FREE")
                    .font(size.fontSize)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(isPro ? .white : AppColors.textSecondary)
        .padding(.horizontal, size.padding.horizontal)
        .padding(.vertical, size.padding.vertical)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isPro ? AppColors.primary : AppColors.surface)
        )
    }
}

// MARK: - Locked Feature Badge

struct LockedFeatureBadge: View {
    let feature: PremiumFeature
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.caption2)
            Text("PRO")
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundColor(AppColors.primary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(AppColors.primary.opacity(0.15))
        )
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
                SmartPremiumBadge(size: .medium)
                Spacer()
                
                // Show expiry for subscribers, or Ambassador note
                switch premiumManager.premiumSource {
                case .subscription:
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
                case .ambassador:
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Club Leader Perk")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("Free Pro Access")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                case .none:
                    EmptyView()
                }
            }
            
            // Status message
            switch premiumManager.premiumSource {
            case .subscription:
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
                
            case .ambassador:
                Text("Thanks for growing the MARCH community! Pro is free while you lead a club with 5+ members.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .none:
                EmptyView()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(premiumManager.isAmbassador ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(premiumManager.isAmbassador ? Color.orange.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
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

