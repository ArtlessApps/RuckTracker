// TrophyCaseView.swift
// Trophy Case UI for displaying earned and available badges
//
// Shows user's achievement progress with earned badges in full color
// and locked badges in grayscale to show what's achievable.

import SwiftUI

// MARK: - Trophy Case View

/// Displays all available badges, highlighting earned ones
struct TrophyCaseView: View {
    /// IDs of badges the user has earned
    let earnedBadgeIds: [String]
    
    /// Whether to show the section header
    var showHeader: Bool = true
    
    /// Number of columns in the grid
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showHeader {
                headerView
            }
            
            badgeGrid
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundColor(AppColors.primary)
            
            Text("Trophy Case")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
            
            // Badge count
            Text("\(earnedBadgeIds.count)/\(BadgeCatalog.allBadges.count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppColors.surface)
                )
        }
    }
    
    // MARK: - Badge Grid
    
    private var badgeGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(BadgeCatalog.allBadges) { badge in
                let isEarned = earnedBadgeIds.contains(badge.id)
                BadgeItemView(badge: badge, isEarned: isEarned)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Badge Item View

/// Individual badge display in the trophy case
struct BadgeItemView: View {
    let badge: Badge
    let isEarned: Bool
    
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            VStack(spacing: 8) {
                // Badge icon
                ZStack {
                    // Background circle with gradient for earned, gray for locked
                    Circle()
                        .fill(
                            isEarned
                                ? badge.tier.gradient
                                : LinearGradient(
                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 56, height: 56)
                    
                    // Icon
                    Image(systemName: badge.iconSystemName)
                        .font(.system(size: 24))
                        .foregroundColor(isEarned ? .white : Color.gray.opacity(0.5))
                    
                    // Lock overlay for unearned badges
                    if !isEarned {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                            .offset(x: 18, y: 18)
                    }
                }
                
                // Badge name
                Text(badge.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isEarned ? AppColors.textPrimary : AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 28)
            }
        }
        .buttonStyle(.plain)
        .opacity(isEarned ? 1.0 : 0.6)
        .sheet(isPresented: $showingDetail) {
            BadgeDetailView(badge: badge, isEarned: isEarned)
        }
    }
}

// MARK: - Badge Detail View

/// Full detail view for a badge
struct BadgeDetailView: View {
    let badge: Badge
    let isEarned: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Large badge icon
                    ZStack {
                        // Outer glow for earned badges
                        if isEarned {
                            Circle()
                                .fill(badge.color.opacity(0.2))
                                .frame(width: 160, height: 160)
                                .blur(radius: 20)
                        }
                        
                        // Main badge circle
                        Circle()
                            .fill(
                                isEarned
                                    ? badge.tier.gradient
                                    : LinearGradient(
                                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: isEarned ? badge.color.opacity(0.5) : Color.clear, radius: 20)
                        
                        // Icon
                        Image(systemName: badge.iconSystemName)
                            .font(.system(size: 48))
                            .foregroundColor(isEarned ? .white : Color.gray.opacity(0.5))
                        
                        // Lock for unearned
                        if !isEarned {
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "lock.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    // Badge info
                    VStack(spacing: 12) {
                        Text(badge.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        // Tier badge
                        Text(badge.tier.displayName.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(isEarned ? badge.color : Color.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill((isEarned ? badge.color : Color.gray).opacity(0.15))
                            )
                        
                        Text(badge.description)
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Status
                    if isEarned {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Earned")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                        )
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.title2)
                                .foregroundColor(AppColors.textSecondary)
                            Text("Not Yet Earned")
                                .font(.headline)
                                .foregroundColor(AppColors.textSecondary)
                            Text("Keep rucking to unlock this badge!")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.surface)
                        )
                    }
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Compact Trophy Case (for Profile integration)

/// A more compact version of the trophy case for embedding in other views
struct CompactTrophyCaseView: View {
    let earnedBadgeIds: [String]
    let maxBadgesToShow: Int = 6
    
    @State private var showingFullTrophyCase = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    /// Badges to display (prioritize earned, then fill with locked)
    private var displayBadges: [Badge] {
        let earned = BadgeCatalog.allBadges.filter { earnedBadgeIds.contains($0.id) }
        let locked = BadgeCatalog.allBadges.filter { !earnedBadgeIds.contains($0.id) }
        
        // Show earned first, then locked to fill remaining slots
        let combined = earned + locked
        return Array(combined.prefix(maxBadgesToShow))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with view all button
            Button {
                showingFullTrophyCase = true
            } label: {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(AppColors.primary)
                    
                    Text("Trophy Case")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(earnedBadgeIds.count) earned")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            
            // Mini badge grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(displayBadges) { badge in
                    let isEarned = earnedBadgeIds.contains(badge.id)
                    MiniBadgeView(badge: badge, isEarned: isEarned)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .sheet(isPresented: $showingFullTrophyCase) {
            FullTrophyCaseSheet(earnedBadgeIds: earnedBadgeIds)
        }
    }
}

// MARK: - Mini Badge View

/// Smaller badge for compact display
struct MiniBadgeView: View {
    let badge: Badge
    let isEarned: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    isEarned
                        ? badge.tier.gradient
                        : LinearGradient(
                            colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .frame(width: 44, height: 44)
            
            Image(systemName: badge.iconSystemName)
                .font(.system(size: 18))
                .foregroundColor(isEarned ? .white : Color.gray.opacity(0.4))
            
            if !isEarned {
                Circle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 44, height: 44)
            }
        }
        .opacity(isEarned ? 1.0 : 0.5)
    }
}

// MARK: - Full Trophy Case Sheet

/// Full-screen trophy case presented as a sheet
struct FullTrophyCaseSheet: View {
    let earnedBadgeIds: [String]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Stats header
                        statsHeader
                        
                        // Full trophy case
                        TrophyCaseView(earnedBadgeIds: earnedBadgeIds, showHeader: false)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Trophy Case")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var statsHeader: some View {
        HStack(spacing: 24) {
            StatItem(
                value: "\(earnedBadgeIds.count)",
                label: "Earned"
            )
            
            StatItem(
                value: "\(BadgeCatalog.allBadges.count - earnedBadgeIds.count)",
                label: "Locked"
            )
            
            StatItem(
                value: "\(Int(Double(earnedBadgeIds.count) / Double(BadgeCatalog.allBadges.count) * 100))%",
                label: "Complete"
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview("Trophy Case - Some Earned") {
    TrophyCaseView(earnedBadgeIds: ["pro_athlete", "100_mile_club", "week_warrior"])
        .padding()
        .background(AppColors.backgroundGradient)
}

#Preview("Trophy Case - None Earned") {
    TrophyCaseView(earnedBadgeIds: [])
        .padding()
        .background(AppColors.backgroundGradient)
}

#Preview("Compact Trophy Case") {
    CompactTrophyCaseView(earnedBadgeIds: ["pro_athlete", "100_mile_club"])
        .padding()
        .background(AppColors.backgroundGradient)
}

#Preview("Badge Detail - Earned") {
    BadgeDetailView(badge: BadgeCatalog.proAthlete, isEarned: true)
}

#Preview("Badge Detail - Locked") {
    BadgeDetailView(badge: BadgeCatalog.selectionReady, isEarned: false)
}
