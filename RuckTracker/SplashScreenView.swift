import SwiftUI

struct SplashScreenView: View {
    @Binding var showingSplash: Bool
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            // Dark background
            Color("BackgroundDark")
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                // MARCH text in burnt sienna
                Text("MARCH")
                    .font(.system(size: 72, weight: .black, design: .default))
                    .foregroundColor(Color("PrimaryMain"))
                    .tracking(2)
                
                // WALK STRONGER subtitle in white
                Text("WALK STRONGER")
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(.white)
                    .tracking(4)
            }
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

