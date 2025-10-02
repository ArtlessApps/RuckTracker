import SwiftUI

struct AuthenticationRequiredView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var supabaseManager: SupabaseManager
    @State private var showingLoginOptions = false
    
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
                    BenefitRow(icon: "person.2", title: "Sync Across Devices", description: "Access your data anywhere")
                    BenefitRow(icon: "chart.line.uptrend.xyaxis", title: "Track Progress", description: "Monitor your improvement over time")
                    BenefitRow(icon: "trophy", title: "Join Programs", description: "Participate in structured training")
                    BenefitRow(icon: "person.3", title: "Leaderboards", description: "Compete with other ruckers")
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Sign Up Button
                VStack(spacing: 16) {
                    Button {
                        showingLoginOptions = true
                    } label: {
                        Text("Get Started")
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
                    
                    Text("Sign up to sync your data and access all features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingLoginOptions) {
            LoginOptionsView()
        }
    }
}

struct BenefitRow: View {
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

#Preview {
    AuthenticationRequiredView()
        .environmentObject(AuthService())
        .environmentObject(SupabaseManager.shared)
}
