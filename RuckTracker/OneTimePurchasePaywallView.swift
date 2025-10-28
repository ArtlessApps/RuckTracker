import SwiftUI
import StoreKit

struct OneTimePurchasePaywallView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
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
                    colors: [Color("PrimaryMain").opacity(0.1), .blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
                        featuresSection
                        pricingSection
                        purchaseButton
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
                if storeManager.proUnlockProduct == nil {
                    await storeManager.loadProducts()
                }
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
                .foregroundColor(Color("PrimaryMain"))
                .symbolEffect(.pulse)
            
            Text("Unlock Pro")
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
            return "Get all 10 training programs and weekly challenges"
        case .programAccess:
            return "Unlock professional training programs for serious ruckers"
        case .settings:
            return "Access all pro features with a one-time purchase"
        case .featureUpsell:
            return "Unlock all programs and challenges"
        }
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                PaywallFeatureRow(
                    icon: "figure.hiking",
                    title: "10 Training Programs",
                    description: "Beginner to elite programs (4-12 weeks each)"
                )
                
                PaywallFeatureRow(
                    icon: "trophy.fill",
                    title: "8 Weekly Challenges",
                    description: "Power, Speed, Distance, and Recovery focus weeks"
                )
                
                PaywallFeatureRow(
                    icon: "chart.bar.fill",
                    title: "Unlimited History",
                    description: "Track all your rucks with no limits"
                )
                
                PaywallFeatureRow(
                    icon: "star.fill",
                    title: "Achievement System",
                    description: "Unlock badges and track your accomplishments"
                )
            }
        }
    }
    
    // MARK: - Pricing Section
    
    private var pricingSection: some View {
        VStack(spacing: 12) {
            if let product = storeManager.proUnlockProduct {
                VStack(spacing: 8) {
                    Text("One-Time Unlock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(product.displayPrice)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color("PrimaryMain"))
                    
                    Text("Pay once, own forever")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("All programs & challenges included")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
            }
        }
    }
    
    // MARK: - Purchase Button
    
    private var purchaseButton: some View {
        Button(action: handlePurchase) {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Unlock Pro")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color("PrimaryMain"))
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(isPurchasing || storeManager.proUnlockProduct == nil)
    }
    
    private func handlePurchase() {
        guard let product = storeManager.proUnlockProduct else { return }
        
        isPurchasing = true
        
        Task {
            do {
                _ = try await storeManager.purchase(product)
                
                // Check if purchase was successful
                if storeManager.hasProUnlock {
                    dismiss()
                }
            } catch {
                print("Purchase failed: \(error)")
                // Error handling is already managed by StoreKitManager
            }
            
            isPurchasing = false
        }
    }
    
    // MARK: - Legal Links
    
    private var legalLinksSection: some View {
        HStack(spacing: 20) {
            Button("Terms of Service") {
                showingTerms = true
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Text("•")
                .foregroundColor(.secondary)
            
            Button("Privacy Policy") {
                showingPrivacy = true
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Restore") {
                Task {
                    await storeManager.restorePurchases()
                }
            }
            .font(.caption)
            .foregroundColor(Color("PrimaryMain"))
        }
    }
}

// MARK: - Paywall Feature Row Component

struct PaywallFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color("PrimaryMain"))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OneTimePurchasePaywallView(context: .programAccess)
}
