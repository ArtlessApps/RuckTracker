import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    
    let context: PaywallContext
    var onMaybeLater: (() -> Void)? = nil  // Callback for "Maybe Later" action
    
    enum PaywallContext {
        case onboarding           // During initial onboarding
        case planGeneration       // After generating a custom plan (the "magic moment")
        case programAccess        // Trying to access a specific program
        case settings             // From settings menu
        case featureUpsell        // Generic feature upsell
        case profileUpgrade       // From profile screen
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
                        valuePropositionTagline
                        featuresSection
                        subscriptionOptionsSection
                        callToActionSection
                        legalLinksSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Show close button for non-blocking contexts
                if context != .onboarding && context != .planGeneration {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Later") {
                            handleMaybeLater()
                        }
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .task {
                if storeManager.availableSubscriptions.isEmpty {
                    await storeManager.loadProducts()
                }
                // Pre-select recommended subscription
                selectedProduct = storeManager.recommendedSubscription
            }
            .alert("Purchase Error", isPresented: $storeManager.showingPurchaseError) {
                Button("OK") { }
            } message: {
                Text(storeManager.purchaseError?.localizedDescription ?? "Unknown error")
            }
            .sheet(isPresented: $showingTerms) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showingPrivacy) {
                PrivacyPolicyView()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.primary)
                .symbolEffect(.pulse)
            
            Text(contextHeadline)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(contextDescription)
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Value Proposition
    
    private var valuePropositionTagline: some View {
        Text("Your Digital Coach")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppColors.primary.opacity(0.1))
            )
    }
    
    private var contextHeadline: String {
        switch context {
        case .planGeneration:
            return "Unlock Your Custom Plan"
        case .onboarding, .programAccess:
            return "Upgrade to MARCH Pro"
        case .settings, .featureUpsell, .profileUpgrade:
            return "Upgrade to MARCH Pro"
        }
    }
    
    private var contextDescription: String {
        switch context {
        case .planGeneration:
            return "Train effectively with progress tracking and smart targets."
        case .onboarding:
            return "Get personalized training plans and analytics for serious ruckers"
        case .programAccess:
            return "Access all 10+ military-backed training programs and weekly challenges"
        case .settings:
            return "Unlock all Pro features and personalized training"
        case .featureUpsell:
            return "Get the complete rucking training experience"
        case .profileUpgrade:
            return "Take your rucking to the next level with Pro features"
        }
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                FeatureRow(
                    icon: "sparkles",
                    title: "Dynamic Plan Generator",
                    description: "AI-generated training tailored to your goals and schedule"
                )
                
                FeatureRow(
                    icon: "figure.hiking",
                    title: "10+ Structured Programs",
                    description: "GORUCK Prep, Selection Prep, military-researched plans"
                )
                
                FeatureRow(
                    icon: "chart.xyaxis.line",
                    title: "Heavy Hauler Analytics",
                    description: "Tonnage trends, vertical gain analysis, progress over time"
                )
                
                FeatureRow(
                    icon: "globe",
                    title: "Global Leaderboards",
                    description: "Rank against ruckers worldwide, not just your club"
                )
                
            }
        }
    }
    
    // MARK: - Subscription Options
    
    private var subscriptionOptionsSection: some View {
        VStack(spacing: 16) {
            Text("Choose Your Plan")
                .font(.title2)
                .fontWeight(.semibold)
            
            if storeManager.isLoading {
                ProgressView("Loading options...")
                    .frame(height: 100)
            } else {
                subscriptionOptions
            }
        }
    }
    
    @ViewBuilder
    private var subscriptionOptions: some View {
        if storeManager.availableSubscriptions.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.title2)
                    .foregroundColor(AppColors.textSecondary)
                
                Text("Unable to load subscription options")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                
                Button("Retry") {
                    Task {
                        await storeManager.loadProducts()
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(height: 100)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: storeManager.availableSubscriptions.count), spacing: 16) {
                ForEach(storeManager.availableSubscriptions, id: \.id) { product in
                    SubscriptionOptionCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        discount: product.isYearlySubscription ? storeManager.yearlyDiscount() : nil
                    ) {
                        selectedProduct = product
                    }
                }
            }
        }
    }
    
    // MARK: - Call to Action
    
    private var callToActionSection: some View {
        VStack(spacing: 16) {
            if let selectedProduct = selectedProduct {
                Button {
                    Task {
                        do {
                            // Tag purchase with current user's UUID for per-user subscription tracking
                            let userToken = CommunityService.shared.currentProfile?.id
                            let transaction = try await storeManager.purchase(selectedProduct, appAccountToken: userToken)
                            if let transaction = transaction {
                                // Purchase successful - record in user_subscriptions + grant premium
                                premiumManager.handleSuccessfulPurchase(transaction: transaction)
                                
                                // Dismiss the paywall
                                // Use both methods to ensure dismissal works regardless of how
                                // the paywall was presented (via $premiumManager.showingPaywall 
                                // or via a local @State variable)
                                premiumManager.dismissPaywall()
                                dismiss()
                                
                                // Add a small delay to ensure the post-purchase prompt
                                // is shown after the paywall is fully dismissed
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                            }
                        } catch {
                            // Error handling is done in StoreKitManager
                        }
                    }
                } label: {
                    HStack {
                        if storeManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text("Start Free Trial")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primaryGradient)
                    .foregroundColor(AppColors.textPrimary)
                    .cornerRadius(12)
                }
                .disabled(storeManager.isLoading)
                
                Text("Free for 7 days, then \(selectedProduct.localizedPrice) \(selectedProduct.subscriptionPeriodDescription.lowercased()). Cancel anytime.")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // "Maybe Later" / Use Free Version button
            Button {
                handleMaybeLater()
            } label: {
                Text(maybeLaterText)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            .disabled(storeManager.isLoading)
            
            Button("Restore Purchases") {
                Task {
                    await storeManager.restorePurchases()
                    // Check if restored entitlements include one for the current user
                    if let userId = CommunityService.shared.currentProfile?.id,
                       let entitlement = await storeManager.activeEntitlement(for: userId) {
                        premiumManager.handleSuccessfulPurchase(transaction: entitlement)
                        premiumManager.dismissPaywall()
                        dismiss()
                    } else if !CommunityService.shared.isAuthenticated && storeManager.isSubscribed {
                        // Anonymous user - any active entitlement counts
                        premiumManager.dismissPaywall()
                        dismiss()
                    }
                }
            }
            .font(.caption)
            .foregroundColor(AppColors.primary.opacity(0.7))
            .disabled(storeManager.isLoading)
        }
    }
    
    private var maybeLaterText: String {
        switch context {
        case .planGeneration:
            return "Use Free Version"
        case .onboarding:
            return "Maybe Later"
        default:
            return "Not Now"
        }
    }
    
    private func handleMaybeLater() {
        // Execute callback if provided (for navigation control)
        onMaybeLater?()
        
        // Dismiss the paywall
        dismiss()
    }
    
    // MARK: - Legal Links
    
    private var legalLinksSection: some View {
        VStack(spacing: 8) {
            Text("By subscribing, you agree to MARCH's Terms of Service and Privacy Policy. Subscriptions auto-renew unless cancelled 24 hours before the next billing period.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button("Terms of Service") {
                    showingTerms = true
                }
                .font(.caption)
                .foregroundColor(AppColors.primary)
                
                Button("Privacy Policy") {
                    showingPrivacy = true
                }
                .font(.caption)
                .foregroundColor(AppColors.primary)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Supporting Views

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppColors.primary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct SubscriptionOptionCard: View {
    let product: Product
    let isSelected: Bool
    let discount: String?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Badge for yearly discount
                if let discount = discount {
                    Text("Save \(discount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.primary.opacity(0.2))
                        .cornerRadius(6)
                } else {
                    // Spacer to maintain consistent height
                    Text("")
                        .font(.caption)
                        .padding(.vertical, 4)
                }
                
                VStack(spacing: 4) {
                    Text(product.subscriptionPeriodDescription)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(product.localizedPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if product.isYearlySubscription {
                        if let monthlyPrice = calculateMonthlyPrice() {
                            Text("\(monthlyPrice)/month")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                
                // Popular badge for yearly
                if product.isYearlySubscription {
                    Text("Most Popular")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func calculateMonthlyPrice() -> String? {
        let monthlyPrice = product.price / 12
        return product.priceFormatStyle.format(monthlyPrice)
    }
}

// MARK: - Legal Views

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text("""
                Terms of Service
                
                Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))
                
                1. Acceptance of Terms
                By downloading and using MARCH, you agree to these terms.
                
                2. Subscription Terms
                - Premium subscriptions auto-renew unless cancelled
                - Cancel anytime in App Store settings
                - No refunds for partial periods
                - Free trial converts to paid subscription if not cancelled
                
                3. User Responsibilities
                - Provide accurate health information
                - Use app safely during workouts
                - Don't share account credentials
                
                4. Privacy
                Your health data remains private and is processed locally on your device.
                
                5. Limitation of Liability
                Use MARCH at your own risk. Consult healthcare providers before starting new exercise programs.
                """)
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text("""
                Privacy Policy
                
                Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))
                
                MARCH is committed to protecting your privacy.
                
                Data We Collect:
                - Workout data (distance, time, calories) - stored locally
                - Health data via HealthKit - remains on your device
                - App usage analytics - anonymized
                
                Data We Don't Collect:
                - Personal health information
                - Location data outside of workouts
                - Contact information (unless you contact support)
                
                Data Storage:
                - All personal data stored locally on your device
                - Workout summaries synced via iCloud (encrypted)
                - No third-party data sharing
                
                Your Rights:
                - Delete app to remove all data
                - Manage HealthKit permissions in iOS Settings
                - Contact us for data questions
                
                Contact: privacy@theruckworkout.com
                """)
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SubscriptionPaywallView(context: .programAccess)
}
