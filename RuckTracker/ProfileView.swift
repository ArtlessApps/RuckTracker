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
                    // Simplified Profile Info
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
    
    /// Returns user-friendly subscription status
    private var subscriptionStatusText: String {
        if premiumManager.isPremiumUser {
            if premiumManager.isInFreeTrial {
                return "Premium (Trial)"
            } else {
                return "Premium"
            }
        } else {
            return "Free"
        }
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
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
            
            Divider()
            
            // Simple subscription status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(subscriptionStatusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
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
            
            if premiumManager.isPremiumUser {
                premiumUserView
            } else {
                freeUserView
            }
        }
    }
    
    private var premiumUserView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    if premiumManager.isInFreeTrial {
                        Text("Premium Trial Active")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let expiryDate = premiumManager.subscriptionExpiryDate {
                            Text("Trial ends \(expiryDate, style: .date)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Premium Active")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let expiryDate = premiumManager.subscriptionExpiryDate {
                            Text("Renews \(expiryDate, style: .date)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Premium features list
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "chart.xyaxis.line", text: "Advanced analytics")
                FeatureRow(icon: "folder.fill", text: "Training programs")
                FeatureRow(icon: "trophy.fill", text: "Challenges & achievements")
                FeatureRow(icon: "square.and.arrow.down.fill", text: "Data export")
            }
            .padding(.top, 4)
            
            // Manage subscription button
            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Manage Subscription")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 1)
                    )
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

// MARK: - Feature Row Helper

private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Username Editor View

struct UsernameEditorView: View {
    let currentUsername: String?
    let onSave: (String) -> Void
    
    @State private var username: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(username)
                        dismiss()
                    }
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            username = currentUsername ?? ""
        }
    }
}

#Preview {
    ProfileView()
}