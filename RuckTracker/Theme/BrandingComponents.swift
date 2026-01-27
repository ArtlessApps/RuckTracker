import SwiftUI

/// Reusable branding components for consistent MARCH identity across all screens
/// Use these instead of recreating the logo/tagline manually each time

// MARK: - MARCH Logo
/// The main MARCH logo with consistent styling
/// - Parameter size: The logo size (.small, .medium, .large, .splash)
struct MARCHLogo: View {
    enum Size {
        case small      // For compact spaces (32pt)
        case medium     // For onboarding steps (48pt)
        case large      // For main screens (60pt)
        case splash     // For splash screen (72pt)
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 48
            case .large: return 60
            case .splash: return 72
            }
        }
        
        var tracking: CGFloat {
            switch self {
            case .small: return 1
            case .medium: return 1.5
            case .large: return 2
            case .splash: return 2
            }
        }
    }
    
    let size: Size
    
    var body: some View {
        Text("MARCH")
            .font(.system(size: size.fontSize, weight: .black, design: .default))
            .foregroundColor(AppColors.primary)  // Always electric green
            .tracking(size.tracking)
    }
}

// MARK: - MARCH Tagline
/// The "WALK STRONGER" tagline with consistent styling
/// - Parameter size: The tagline size (.small, .medium, .large)
struct MARCHTagline: View {
    enum Size {
        case small      // For compact spaces (10pt)
        case medium     // For onboarding/screens (14pt)
        case large      // For splash/main screens (18pt)
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 14
            case .large: return 18
            }
        }
        
        var tracking: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 3
            case .large: return 4
            }
        }
    }
    
    let size: Size
    
    var body: some View {
        Text("WALK STRONGER")
            .font(.system(size: size.fontSize, weight: .medium, design: .default))
            .foregroundColor(AppColors.textPrimary)  // Always white
            .tracking(size.tracking)
    }
}

// MARK: - MARCH Branding Stack
/// Complete MARCH branding (logo + tagline) in a vertical stack
/// - Parameter logoSize: The size of the logo (tagline scales proportionally)
/// - Parameter spacing: Space between logo and tagline (default: 8)
struct MARCHBranding: View {
    let logoSize: MARCHLogo.Size
    let spacing: CGFloat
    
    init(logoSize: MARCHLogo.Size = .large, spacing: CGFloat = 8) {
        self.logoSize = logoSize
        self.spacing = spacing
    }
    
    var body: some View {
        VStack(spacing: spacing) {
            MARCHLogo(size: logoSize)
            
            // Tagline size matches logo size
            MARCHTagline(size: matchingTaglineSize)
        }
    }
    
    /// Maps logo size to appropriate tagline size
    private var matchingTaglineSize: MARCHTagline.Size {
        switch logoSize {
        case .small:
            return .small
        case .medium:
            return .medium
        case .large, .splash:
            return .large
        }
    }
}

// MARK: - Usage Examples in Comments
/*
 
 EXAMPLE USAGE:
 
 // Splash Screen
 MARCHBranding(logoSize: .splash)
 
 // Onboarding Welcome
 MARCHBranding(logoSize: .large)
 
 // Watch Onboarding
 MARCHBranding(logoSize: .medium, spacing: 4)
 
 // Small Logo Only (for headers)
 MARCHLogo(size: .small)
 
 // Custom Branding
 VStack(spacing: 4) {
     MARCHLogo(size: .medium)
     MARCHTagline(size: .small)
 }
 
 */

