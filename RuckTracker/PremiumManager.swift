import Foundation
import SwiftUI
import Combine

@MainActor
class PremiumManager: ObservableObject {
    static let shared = PremiumManager()
    
    @Published var isPremiumUser = false
    @Published var subscriptionExpiryDate: Date?
    @Published var showingPaywall = false
    @Published var paywallContext: SubscriptionPaywallView.PaywallContext = .featureUpsell
    
    private let storeKitManager = StoreKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSubscriptions()
        updatePremiumStatus()
    }
    
    private func setupSubscriptions() {
        // Listen to subscription status changes
        storeKitManager.$subscriptionStatus
            .sink { [weak self] status in
                self?.updatePremiumStatus()
            }
            .store(in: &cancellables)
        
        // Listen to system notifications
        NotificationCenter.default.publisher(for: .subscriptionStatusChanged)
            .sink { [weak self] _ in
                self?.updatePremiumStatus()
            }
            .store(in: &cancellables)
    }
    
    private func updatePremiumStatus() {
        isPremiumUser = storeKitManager.isSubscribed
        subscriptionExpiryDate = storeKitManager.subscriptionExpiryDate
        
        print("🔐 Premium status updated: \(isPremiumUser ? "Premium" : "Free")")
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
    case advancedAnalytics
    case communityFeatures
    case cloudSync
    case unlimitedWorkouts
    case exportData
    case customTrainingPlans
    case nutritionTracking
    case leaderboards
    
    var requiresPremium: Bool {
        switch self {
        case .trainingPrograms, .advancedAnalytics, .communityFeatures, .cloudSync, .exportData, .customTrainingPlans, .nutritionTracking, .leaderboards:
            return true
        case .unlimitedWorkouts:
            return false // Free users get unlimited workouts for now
        }
    }
    
    var displayName: String {
        switch self {
        case .trainingPrograms:
            return "Training Programs"
        case .advancedAnalytics:
            return "Advanced Analytics"
        case .communityFeatures:
            return "Community Features"
        case .cloudSync:
            return "Cloud Sync"
        case .unlimitedWorkouts:
            return "Unlimited Workouts"
        case .exportData:
            return "Export Data"
        case .customTrainingPlans:
            return "Custom Training Plans"
        case .nutritionTracking:
            return "Nutrition Tracking"
        case .leaderboards:
            return "Leaderboards"
        }
    }
    
    var description: String {
        switch self {
        case .trainingPrograms:
            return "Access structured 8-16 week programs designed by military professionals"
        case .advancedAnalytics:
            return "Detailed progress charts, performance insights, and workout analysis"
        case .communityFeatures:
            return "Join challenges, compete with others, and share achievements"
        case .cloudSync:
            return "Sync your data across all devices and never lose your progress"
        case .unlimitedWorkouts:
            return "Track as many workouts as you want without limits"
        case .exportData:
            return "Export your workout data to CSV or other fitness apps"
        case .customTrainingPlans:
            return "Create personalized training plans based on your goals"
        case .nutritionTracking:
            return "Track nutrition and hydration for optimal performance"
        case .leaderboards:
            return "Compete with others and track your progress on leaderboards"
        }
    }
    
    var iconName: String {
        switch self {
        case .trainingPrograms:
            return "figure.hiking"
        case .advancedAnalytics:
            return "chart.line.uptrend.xyaxis"
        case .communityFeatures:
            return "person.2.fill"
        case .cloudSync:
            return "icloud.and.arrow.up"
        case .unlimitedWorkouts:
            return "infinity"
        case .exportData:
            return "square.and.arrow.up"
        case .customTrainingPlans:
            return "doc.text"
        case .nutritionTracking:
            return "fork.knife"
        case .leaderboards:
            return "trophy.fill"
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
                    .foregroundColor(.orange)
                
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
                            .stroke(Color.orange, lineWidth: 2)
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
                colors: [.orange, .red],
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
                        .foregroundColor(.orange)
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
                            .foregroundColor(.orange)
                        Text("Upgrade to Pro")
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
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

