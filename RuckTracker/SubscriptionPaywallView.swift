import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    
    let context: PaywallContext
    
    enum PaywallContext {
        case onboarding
        case programAccess
        case settings
        case featureUpsell
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.orange.opacity(0.1), .blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
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
                if context != .onboarding {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Later") {
                            dismiss()
                        }
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
            .sheet(isPresented: $storeManager.showingPostPurchasePrompt) {
                PostPurchaseAccountPrompt(
                    onAccountCreated: {
                        storeManager.dismissPostPurchasePrompt()
                    },
                    onSkip: {
                        storeManager.dismissPostPurchasePrompt()
                    }
                )
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
                .symbolEffect(.pulse)
            
            Text("Upgrade to Pro")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(contextDescription)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var contextDescription: String {
        switch context {
        case .onboarding:
            return "Get access to professional training programs and advanced analytics"
        case .programAccess:
            return "Unlock structured training programs designed by military professionals"
        case .settings:
            return "Upgrade to access all premium features and training programs"
        case .featureUpsell:
            return "This feature requires a Pro subscription"
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
                    icon: "figure.hiking",
                    title: "Training Programs",
                    description: "Structured 8-16 week programs by military experts"
                )
                
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Advanced Analytics",
                    description: "Detailed progress tracking and performance insights"
                )
                
                FeatureRow(
                    icon: "person.2.fill",
                    title: "Community Challenges",
                    description: "Join events and compete with other ruckers"
                )
                
                FeatureRow(
                    icon: "trophy.fill",
                    title: "Achievement System",
                    description: "Unlock badges and track your accomplishments"
                )
                
                FeatureRow(
                    icon: "icloud.and.arrow.down",
                    title: "Cloud Sync",
                    description: "Access your data across all devices"
                )
                
                FeatureRow(
                    icon: "heart.fill",
                    title: "Support Development",
                    description: "Help us build more features and improve the app"
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
                    .foregroundColor(.secondary)
                
                Text("Unable to load subscription options")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
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
                            let transaction = try await storeManager.purchase(selectedProduct)
                            if transaction != nil {
                                // Purchase successful, dismiss paywall
                                dismiss()
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
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(storeManager.isLoading)
                
                Text("Free for 7 days, then \(selectedProduct.localizedPrice) \(selectedProduct.subscriptionPeriodDescription.lowercased())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Restore Purchases") {
                Task {
                    await storeManager.restorePurchases()
                }
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .disabled(storeManager.isLoading)
        }
    }
    
    // MARK: - Legal Links
    
    private var legalLinksSection: some View {
        VStack(spacing: 8) {
            Text("By subscribing, you agree to our Terms of Service and Privacy Policy. Subscriptions auto-renew unless cancelled 24 hours before the next billing period.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button("Terms of Service") {
                    showingTerms = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("Privacy Policy") {
                    showingPrivacy = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
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
                        .foregroundColor(.primary)
                    
                    Text(product.localizedPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if product.isYearlySubscription {
                        if let monthlyPrice = calculateMonthlyPrice() {
                            Text("\(monthlyPrice)/month")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Popular badge for yearly
                if product.isYearlySubscription {
                    Text("Most Popular")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
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
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
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
                By downloading and using RuckTracker, you agree to these terms.
                
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
                Use RuckTracker at your own risk. Consult healthcare providers before starting new exercise programs.
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
                
                RuckTracker is committed to protecting your privacy.
                
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
                
                Contact: support@rucktracker.app
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
