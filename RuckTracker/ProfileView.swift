import SwiftUI

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var premiumManager = PremiumManager.shared
    @StateObject private var userSettings = UserSettings.shared
    @State private var showingLogoutAlert = false
    @State private var activeSheet: ActiveSheet? = nil
    
    enum ActiveSheet: Identifiable {
        case usernameEditor
        
        var id: Int {
            switch self {
            case .usernameEditor: return 0
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Streamlined Profile Info
                    profileHeaderSection
                    
                    // Subscription Details (if premium or show upgrade)
                    subscriptionDetailsSection
                    
                    // Actions
                    actionsSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .usernameEditor:
                UsernameEditorView(currentUsername: userSettings.username) { newUsername in
                    userSettings.username = newUsername
                }
            }
        }
        .sheet(isPresented: $premiumManager.showingPaywall) {
            SubscriptionPaywallView(context: premiumManager.paywallContext)
        }
        .onAppear {
            print("📱 ProfileView appeared - local mode")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns user-friendly account status text
    /// App User: Anonymous user without email
    /// Connected: User with email
    /// Premium: Based on subscription status (independent of email)
    private var accountStatusText: String {
        let premiumStatus: String = {
            if premiumManager.isPremiumUser {
                if premiumManager.isInTrialPeriod {
                    return "Premium (Trial)"
                } else {
                    return "Premium"
                }
            } else {
                return "Free"
            }
        }()
        
        // Connection status (authentication tier)
        return premiumStatus // "Free" or "Premium" or "Premium (Trial)"
    }
    
    /// Returns color for account status badge
    private var accountStatusColor: Color {
        if premiumManager.isPremiumUser {
            return .green // Premium = green
        } else {
            return .orange // App User (free) = orange
        }
    }
    
    /// Returns connection status for display
    private var connectionStatusText: String {
        "Local User"
    }
    
    /// Returns connection status color
    private var connectionStatusColor: Color {
        .blue
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        VStack(spacing: 20) {
            // Username with edit button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let username = userSettings.username, !username.isEmpty {
                        Text(username)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    } else {
                        Text("Tap to set username")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    activeSheet = .usernameEditor
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
            }
            
            // Account status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(accountStatusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(accountStatusColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Connection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(connectionStatusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(connectionStatusColor)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    
    // MARK: - Subscription Details Section
    
    private var subscriptionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subscription")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if premiumManager.isPremiumUser {
                activeSubscriptionView
            } else {
                freeUserView
            }
        }
    }
    
    private var activeSubscriptionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Premium Active")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if premiumManager.isInTrialPeriod {
                        Text("Trial Period")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Active Subscription")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if let expiryDate = premiumManager.subscriptionExpiryDate {
                HStack {
                    Text("Expires:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(expiryDate, style: .date)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var freeUserView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Account")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Upgrade to Premium for more features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button {
                premiumManager.showPaywall(context: .profileUpgrade)
            } label: {
                Text("Upgrade to Premium")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 16) {
            
        }
    }
}

#Preview {
    ProfileView()
}