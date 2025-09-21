import SwiftUI

// MARK: - Test View for Functional Program Cards
struct ProgramTestView: View {
    @StateObject private var premiumManager = PremiumManager.shared
    @StateObject private var programService = ProgramService()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Test both premium and non-premium states
                    VStack(spacing: 16) {
                        Text("Testing Functional Program Cards")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("This view demonstrates the functional program cards with navigation and enrollment capabilities.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Test the functional program section
                    PremiumTrainingProgramsSection()
                        .environmentObject(premiumManager)
                        .environmentObject(programService)
                    
                    // Test individual functional card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Individual Card Test")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        FunctionalProgramCard(
                            title: "Test Program",
                            description: "This is a test program to verify functionality",
                            difficulty: "Intermediate",
                            weeks: 6,
                            isLocked: false
                        ) {
                            print("Test program card tapped!")
                        }
                    }
                    .padding()
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Program Test")
        }
    }
}

// MARK: - Preview
struct ProgramTestView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramTestView()
    }
}
