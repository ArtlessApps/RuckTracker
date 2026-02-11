import SwiftUI

// MARK: - Hero Ruck Button
/// Primary CTA card that launches an Open Goal ruck session.
/// Styled to match the dashboard tile cards with a primary accent.
struct HeroRuckButton: View {
    let action: () -> Void
    
    /// Sage green to darker teal gradient
    private let heroGradient = LinearGradient(
        colors: [
            AppColors.primary,              // Sage green #00C896
            Color(hex: "007A6E"),           // Mid teal
            Color(hex: "005F56")            // Dark teal
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text("START RUCK")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 2)
                
                Text("No plan. Just walk with weight.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(heroGradient)
                    .shadow(color: AppColors.primary.opacity(0.35), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(HeroButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        AppColors.backgroundGradient
            .ignoresSafeArea()
        
        HeroRuckButton {
            print("START RUCK tapped")
        }
        .padding(.horizontal, 20)
    }
    .preferredColorScheme(.dark)
}
