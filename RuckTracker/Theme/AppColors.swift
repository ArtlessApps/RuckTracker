import SwiftUI

/// Centralized color tokens for the app.
enum AppColors {
    // MARK: - Core Colors
    
    // Black Background
    static let background = Color(hex: "000000") 
    
    // Slightly lighter Navy for Cards/Surfaces (Replaces OffWhite)
    static let surface = Color(hex: "0F2942") 
    
    // A mid-tone blue for secondary backgrounds
    static let surfaceAlt = Color(hex: "1A3A5A") 
    
    // MARK: - Text
    
    static let textPrimary = Color.white
    // Light Grey/Blue for secondary text to blend with navy
    static let textSecondary = Color(hex: "8CA6C1") 
    // Dark text for the rare occasion you are on a light background
    static let textOnLight = Color(hex: "021223")
    
    // MARK: - Brand/Accents
    
    // Electric Green (High contrast against navy)
    static let primary = Color(hex: "00E08F") 
    
    // Secondary Teal
    static let accentGreen = Color(hex: "00C4B4")
    
    // Deep Blue/Teal accent
    static let accentTeal = Color(hex: "005F73")
    
    // Alert/Warm color (muted orange/red that fits blue theme)
    static let accentWarm = Color(hex: "E06C00")
    
    // MARK: - Gradients
    
    /// Use this for your main screen backgrounds
    /// Usage: .background(AppColors.backgroundGradient)
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "000000"),
            Color(hex: "052035")  // Slightly lighter Navy
        ]),
        startPoint: .bottom,
        endPoint: .top
    )
    
    /// Use this for primary buttons or active states
    /// Usage: .foregroundStyle(AppColors.primaryGradient)
    static let primaryGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "00E08F"), // Electric Green
            Color(hex: "00C4B4")  // Teal
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Helper Extension
// This allows you to define colors by Hex in code, bypassing the Asset Catalog for rapid iteration.
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}