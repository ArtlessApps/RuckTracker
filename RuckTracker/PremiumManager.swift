import Foundation
import SwiftUI
import Combine

/// PremiumManager handles premium subscription status
///
/// Key Design Principle:
/// Premium status is determined by StoreKit subscription OR Ambassador status
/// - Premium is tied to Apple ID, NOT user email/authentication
/// - Anonymous users CAN have premium (they purchased via Apple Pay)
/// - Premium persists across sign in/sign out (tied to device's Apple ID)
/// - Club Founders with 5+ members get Pro for free ("Ambassador" status)
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
        
        // Premium status is based on StoreKit subscription status OR Ambassador status
        // Users with valid subscriptions get premium access regardless of authentication status
        // This allows anonymous users who purchase subscriptions to access premium features
        let newPremiumStatus = storeKitSubscribed || isAmbassador
        
        // Always update the status, even if it's the same
        isPremiumUser = newPremiumStatus
        subscriptionExpiryDate = storeKitSubscribed ? newExpiryDate : nil
        
        // Update premium source
        if storeKitSubscribed {
            premiumSource = .subscription
        } else if isAmbassador {
            premiumSource = .ambassador
        } else {
            premiumSource = .none
        }
        
        // Log status changes with more detail
        if wasPremium != isPremiumUser {
            print("🔐 Premium status updated: \(isPremiumUser ? "Premium" : "Free")")
            print("🔐 StoreKit subscription: \(storeKitSubscribed)")
            print("🔐 Ambassador status: \(isAmbassador)")
            print("🔐 Premium source: \(premiumSource)")
            if let expiry = newExpiryDate {
                print("🔐 Subscription expiry: \(expiry)")
            }
            
            // Sync premium status to profile for leaderboard crown display
            syncPremiumStatusToProfile()
        } else {
            // Log current status for debugging
            print("🔐 Premium status unchanged: \(isPremiumUser ? "Premium" : "Free")")
        }
    }
    
    // MARK: - Premium Status Sync
    
    /// Sync the local premium status to the user's profile in the database
    /// This enables the PRO crown to show on leaderboards for other users to see
    func syncPremiumStatusToProfile() {
        Task {
            await syncPremiumStatusToProfileAsync()
        }
    }
    
    /// Async version of premium status sync
    private func syncPremiumStatusToProfileAsync() async {
        let communityService = CommunityService.shared
        
        // Must be signed in to sync
        guard communityService.isAuthenticated else {
            print("🔐 Cannot sync premium status - user not authenticated")
            return
        }
        
        do {
            // Update the is_premium column in the profiles table
            try await communityService.updatePremiumStatus(isPremium: isPremiumUser)
            print("🔐 Premium status synced to profile: \(isPremiumUser ? "PRO" : "Free")")
        } catch {
            print("❌ Failed to sync premium status to profile: \(error)")
        }
    }
    
    // MARK: - Ambassador System
    
    /// Check if user qualifies for Ambassador (free Pro) status
    /// Club Founders with 5+ members get Pro for free
    func checkAmbassadorStatus() async {
        let communityService = CommunityService.shared
        
        // Must be signed in
        guard communityService.currentProfile != nil else {
            isAmbassador = false
            updatePremiumStatus()
            return
        }
        
        do {
            // Load user's clubs
            try await communityService.loadMyClubs()
            
            // Check for clubs where user is founder with 5+ members
            var qualifiesAsAmbassador = false
            
            for club in communityService.myClubs {
                // Check if user is founder
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
    // Core Training (Pro)
    case trainingPrograms       // Structured programs (4-12 weeks)
    case weeklyChallenges       // Weekly challenges
    case planExecution          // Starting/executing workouts from plans
    
    // Smart Coaching (Pro)
    case audioCoaching          // Audio cues during workouts
    case heartRateZones         // Heart rate zone tracking
    case intervalTimers         // Smart interval timers
    
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
                colors: [Color("PrimaryMain"), Color("PrimaryMedium")],
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
                    
                    Text("Unlock training programs, smart coaching, and more")
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

