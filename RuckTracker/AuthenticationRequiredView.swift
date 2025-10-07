import SwiftUI

struct AuthenticationRequiredView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var supabaseManager: SupabaseManager
    @State private var showingLoginOptions = false
    @State private var showingExistingUserLogin = false
    @State private var showingDebugOptions = false
    @State private var activeSheet: ActiveSheet? = nil
    
    enum ActiveSheet: Identifiable {
        case loginOptions(LoginMode)
        case existingUserLogin
        case debugOptions
        
        var id: Int {
            switch self {
            case .loginOptions: return 0
            case .existingUserLogin: return 1
            case .debugOptions: return 2
            }
        }
    }
    
    private func checkForExistingSessionOrCreateAnonymous() async {
        // First check if there's an existing session
        await supabaseManager.checkForExistingSession()
        
        // If no existing session, create an anonymous one
        if !supabaseManager.isAuthenticated {
            do {
                try await authService.signInAnonymously()
                print("✅ Created new anonymous session")
            } catch {
                print("❌ Failed to create anonymous session: \(error)")
            }
        } else {
            print("✅ Using existing session")
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // App Icon and Title
                VStack(spacing: 16) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                    
                    Text("RuckTracker")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Track your rucking progress and join programs")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Benefits
                VStack(spacing: 16) {
                    AuthBenefitRow(icon: "person.2", title: "Sync Across Devices", description: "Access your data anywhere")
                    AuthBenefitRow(icon: "chart.line.uptrend.xyaxis", title: "Track Progress", description: "Monitor your improvement over time")
                    AuthBenefitRow(icon: "trophy", title: "Join Programs", description: "Participate in structured training")
                    AuthBenefitRow(icon: "person.3", title: "Leaderboards", description: "Compete with other ruckers")
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Authentication Options
                VStack(spacing: 16) {
                    // Create Account - New User Sign Up
                    Button {
                        activeSheet = .loginOptions(.signUp)
                    } label: {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    
                    // Maybe Later - Continue as Guest
                    Button {
                        Task {
                            await checkForExistingSessionOrCreateAnonymous()
                        }
                    } label: {
                        Text("Maybe Later")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }
                    
                    // I Already Have an Account
                    Button {
                        activeSheet = .existingUserLogin
                    } label: {
                        Text("I Already Have an Account")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Text("Sign up to sync your data and access all features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Debug button (temporary for testing)
                #if DEBUG
                Button {
                    activeSheet = .debugOptions
                } label: {
                    Text("Debug: Clear Session")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                #endif
            }
            .padding()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .loginOptions(let mode):
                LoginOptionsView(mode: mode)
            case .existingUserLogin:
                LoginOptionsView(mode: .signIn)
            case .debugOptions:
                DebugOptionsView()
            }
        }
    }
}

struct AuthBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct DebugOptionsView: View {
    @EnvironmentObject private var supabaseManager: SupabaseManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Debug Options")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Clear any existing Supabase session to test the authentication flow")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await supabaseManager.clearSession()
                            dismiss()
                        }
                    } label: {
                        Text("Clear Session")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        Task {
                            await supabaseManager.forceClearAllSessions()
                            dismiss()
                        }
                    } label: {
                        Text("Force Clear All Sessions")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Debug")
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

#Preview {
    AuthenticationRequiredView()
        .environmentObject(AuthService())
        .environmentObject(SupabaseManager.shared)
}
