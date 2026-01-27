import SwiftUI

struct SplashScreenView: View {
    @Binding var showingSplash: Bool
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            // Dark background
            AppColors.background
                .ignoresSafeArea()
            
            // CHANGED: Uses MARCHBranding component for consistent branding
            MARCHBranding(logoSize: .splash)
            .opacity(opacity)
        }
        .onAppear {
            // Fade in animation
            withAnimation(.easeIn(duration: 0.8)) {
                opacity = 1.0
            }
            
            // Navigate to main view after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showingSplash = false
                }
            }
        }
    }
}

#Preview {
    SplashScreenView(showingSplash: .constant(true))
}

