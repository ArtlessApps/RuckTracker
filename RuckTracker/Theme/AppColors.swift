import SwiftUI

/// Centralized color tokens for the entire app (iPhone + Watch).
/// EDIT COLORS HERE to change them everywhere in the app.
enum AppColors {
    
    // MARK: - Core Backgrounds
    
    /// Pure black background - used as base layer
    static let background = Color(hex: "000000") 
    
    /// Navy surface for cards/containers (replaces old "OffWhite")
    static let surface = Color(hex: "0F2942") 
    
    /// Alternate navy for layered surfaces
    static let surfaceAlt = Color(hex: "1A3A5A") 
    
    /// White card background for contrast (used in challenge cards, etc.)
    static let cardBackground = Color.white
    
    
    // MARK: - Text Colors
    
    /// Primary text - white for dark backgrounds
    static let textPrimary = Color.white
    
    /// Secondary text - light grey/blue for less emphasis
    static let textSecondary = Color(hex: "8CA6C1") 
    
    /// Dark text for rare light backgrounds
    static let textOnLight = Color(hex: "021223")
    
    
    // MARK: - Brand/Primary Actions
    
    /// PRIMARY BRAND COLOR - Electric Green
    /// This is your main brand color for MARCH logo, CTAs, active states
    static let primary = Color(hex: "00C896") 
    
    
    // MARK: - Accent Colors
    
    /// Secondary accent - Teal
    static let accentGreen = Color(hex: "00C4B4")
    
    /// Deep blue/teal accent
    static let accentTeal = Color(hex: "005F73")
    
    /// Warm accent - muted orange for warnings/highlights
    static let accentWarm = Color(hex: "E06C00")
    
    
    // MARK: - Extended Accent Palette (for workout types)
    
    /// Light green - recovery, easy workouts
    static let accentGreenLight = Color(hex: "33E6A3")
    
    /// Deep green - intense, advanced workouts
    static let accentGreenDeep = Color(hex: "00B374")
    
    /// Light teal - beginner, accessible
    static let accentTealLight = Color(hex: "33D4C4")
    
    /// Deep teal - hard efforts, elite
    static let accentTealDeep = Color(hex: "008C7F")
    
    
    // MARK: - System UI Colors
    
    /// Pause button orange (consistent across phone and watch)
    static let pauseOrange = Color(hex: "FF9500")
    
    /// Success/Play green (consistent across phone and watch)
    static let successGreen = Color(hex: "34C759")
    
    /// Destructive/Stop red
    static let destructiveRed = Color(hex: "FF3B30")
    
    
    // MARK: - Overlays & Shadows
    
    /// Black overlay for modals/cards (80% opacity)
    static let overlayBlack = Color.black.opacity(0.8)
    
    /// Black overlay for semi-transparent backgrounds (75% opacity)
    static let overlayBlackSemi = Color.black.opacity(0.75)
    
    /// Black overlay for shadows (30% opacity)
    static let shadowBlack = Color.black.opacity(0.3)
    
    /// Black overlay for light shadows (10% opacity)
    static let shadowBlackLight = Color.black.opacity(0.1)
    
    /// Black overlay for subtle shadows (6% opacity)
    static let shadowBlackSubtle = Color.black.opacity(0.06)
    
    /// Black overlay for very light shadows (2% opacity)
    static let shadowBlackVeryLight = Color.black.opacity(0.02)
    
    /// White overlay for cards/surfaces (5% opacity)
    static let overlayWhiteLight = Color.white.opacity(0.05)
    
    /// White overlay for cards/surfaces (10% opacity)
    static let overlayWhite = Color.white.opacity(0.1)
    
    /// White overlay for cards/surfaces (20% opacity)
    static let overlayWhiteMedium = Color.white.opacity(0.2)
    
    /// White overlay for cards/surfaces (30% opacity)
    static let overlayWhiteStrong = Color.white.opacity(0.3)
    
    /// White overlay for disabled states (60% opacity)
    static let overlayWhiteDisabled = Color.white.opacity(0.6)
    
    
    // MARK: - Gradients
    
    /// Main background gradient - black to navy
    /// USAGE: .background(AppColors.backgroundGradient)
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "000000"),      // Pure black
            Color(hex: "052035")       // Slightly lighter navy
        ]),
        startPoint: .bottom,
        endPoint: .top
    )
    
    /// Primary button/accent gradient - electric green to teal
    /// USAGE: .background(AppColors.primaryGradient)
    static let primaryGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "00E08F"),      // Electric Green
            Color(hex: "00C4B4")       // Teal
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )
}


// MARK: - Helper Extension for Hex Colors
extension Color {
    /// Initialize a Color from a hex string
    /// Example: Color(hex: "FF5733")
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
            (a, r, g, b) = (255, 0, 0, 0)
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
