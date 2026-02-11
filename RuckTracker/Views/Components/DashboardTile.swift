import SwiftUI

// MARK: - Dashboard Tile
/// A reusable "Live Tile" for the Bento Grid on the dashboard.
///
/// Layout (top → bottom):
///   ┌──────────────────┐
///   │ 🔹 icon          │
///   │                   │
///   │   VALUE           │
///   │   subtitle        │
///   │                   │
///   │   TITLE           │
///   └──────────────────┘
struct DashboardTile: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Icon — top left
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                // Value — center / large
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                // Subtitle
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Title — bottom
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
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
        
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            DashboardTile(
                title: "Plan",
                value: "Week 3",
                subtitle: "Day 12 of 42",
                icon: "calendar",
                color: AppColors.primary,
                action: {}
            )
            
            DashboardTile(
                title: "Tribe",
                value: "Event",
                subtitle: "Sat @ 0700",
                icon: "person.3.fill",
                color: AppColors.accentGreen,
                action: {}
            )
            
            DashboardTile(
                title: "Challenges",
                value: "62%",
                subtitle: "March Madness",
                icon: "trophy.fill",
                color: AppColors.accentWarm,
                action: {}
            )
            
            DashboardTile(
                title: "Rankings",
                value: "#14",
                subtitle: "Global • Distance",
                icon: "chart.bar.fill",
                color: .purple,
                action: {}
            )
        }
        .padding(.horizontal, 20)
    }
    .preferredColorScheme(.dark)
}
