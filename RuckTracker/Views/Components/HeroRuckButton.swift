import SwiftUI

// MARK: - Hero Ruck Button
/// Large, action-first CTA that launches an Open Goal ruck session.
struct HeroRuckButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    Image("MarchIconWhite")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                }
                
                // Title
                Text("GO RUCK")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(AppColors.textPrimary)
                
                // Subtitle
                Text("Open Goal  •  GPS Tracking")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                AppColors.primaryGradient,
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: AppColors.primary.opacity(0.25), radius: 16, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        AppColors.backgroundGradient
            .ignoresSafeArea()
        
        HeroRuckButton {
            print("GO RUCK tapped")
        }
        .padding(.horizontal, 20)
    }
    .preferredColorScheme(.dark)
}
