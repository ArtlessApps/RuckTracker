import SwiftUI

// MARK: - Dashboard Tile
/// A full-width card for the dashboard stack.
///
/// Layout:
///   ┌────────────────────────────────┐
///   │  TITLE                  [icon] │
///   │                                │
///   │  info text                     │
///   └────────────────────────────────┘
struct DashboardTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Top row: Title (left) + Icon badge (right)
                HStack(alignment: .top) {
                    Text(title)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Icon badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(color)
                    }
                }
                
                Spacer()
                
                // Info text — bottom left
                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 110)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
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
        
        VStack(spacing: 16) {
            DashboardTile(
                title: "MY PLAN",
                subtitle: "Next Workout",
                icon: "calendar",
                color: Color(hex: "4A9FD9"),
                action: {}
            )
            
            DashboardTile(
                title: "MY TRIBE",
                subtitle: "Join a Tribe",
                icon: "person.3.fill",
                color: Color(hex: "D4A844"),
                action: {}
            )
            
            DashboardTile(
                title: "PROGRAMS",
                subtitle: "Start a Program",
                icon: "list.clipboard.fill",
                color: AppColors.accentWarm,
                action: {}
            )
            
            DashboardTile(
                title: "LEADERBOARD",
                subtitle: "#14 in Global Distance",
                icon: "chart.bar.fill",
                color: .purple,
                action: {}
            )
        }
        .padding(.horizontal, 20)
    }
    .preferredColorScheme(.dark)
}
