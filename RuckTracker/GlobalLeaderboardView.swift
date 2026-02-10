//
//  GlobalLeaderboardView.swift
//  MARCH
//
//  Global Leaderboards - PRO Feature
//  Displays worldwide rankings across multiple metrics:
//  - Distance (weekly), Tonnage (all-time), Elevation (monthly), Consistency (30 days)
//
//  Gated behind PRO subscription with blur overlay for free users.
//

import SwiftUI

// MARK: - Rankings Tab View (Tab Bar Entry Point)

struct RankingsTabView: View {
    var body: some View {
        NavigationView {
            GlobalLeaderboardView()
                .navigationTitle("Rankings")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Global Leaderboard View

struct GlobalLeaderboardView: View {
    @StateObject private var communityService = CommunityService.shared
    @EnvironmentObject var premiumManager: PremiumManager
    @State private var selectedType: GlobalLeaderboardType = .distance
    @State private var entries: [GlobalLeaderboardEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSignedOut = false
    @State private var showingPaywall = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Type selector (horizontal scrollable capsules)
                leaderboardTypePicker
                
                // Content area
                ZStack {
                    if isSignedOut {
                        signedOutView
                    } else if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(message: error)
                    } else if entries.isEmpty {
                        emptyView
                    } else {
                        leaderboardList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // PRO Gate overlay — top level so it covers ALL content states
            if !premiumManager.isPremiumUser && !isSignedOut {
                proGateOverlay
            }
        }
        .background(AppColors.backgroundGradient)
        .task(id: selectedType) {
            await loadLeaderboard()
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionPaywallView(context: .featureUpsell)
        }
    }
    
    // MARK: - Type Picker
    
    private var leaderboardTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(GlobalLeaderboardType.allCases) { type in
                    LeaderboardTypeCapsule(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedType = type
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(AppColors.surface.opacity(0.5))
    }
    
    // MARK: - Leaderboard List
    
    private var leaderboardList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with metric info
                leaderboardHeader
                
                // Leaderboard entries
                LazyVStack(spacing: 1) {
                    ForEach(entries) { entry in
                        GlobalLeaderboardRow(
                            entry: entry,
                            type: selectedType,
                            isCurrentUser: entry.userId == communityService.currentProfile?.id
                        )
                    }
                }
                .background(AppColors.surface)
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.bottom, 100) // Extra space for overlay
        }
    }
    
    // MARK: - Header
    
    private var leaderboardHeader: some View {
        VStack(spacing: 8) {
            Text(selectedType.periodDescription)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            
            HStack(spacing: 8) {
                Image(systemName: selectedType.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.primary)
                
                Text(selectedType.displayName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text("Top 100 Ruckers Worldwide")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - PRO Gate Overlay
    
    private var proGateOverlay: some View {
        ZStack {
            // Blur effect over the list
            Rectangle()
                .fill(.ultraThinMaterial)
                .blur(radius: 6)
                .ignoresSafeArea()
            
            // Lock and CTA
            VStack(spacing: 20) {
                // Lock icon
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(spacing: 8) {
                    Text("Global Rankings")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("See how you stack up against ruckers worldwide")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // CTA Button
                Button(action: { showingPaywall = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                        Text("Unlock Global Rankings")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(AppColors.textOnLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.primaryGradient)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                
                // PRO badge
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                    Text("PRO FEATURE")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(AppColors.primary)
            }
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.surface)
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Signed-Out State
    
    private var signedOutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary)
            
            Text("Sign In for Rankings")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Create an account or sign in to see how you stack up against ruckers worldwide.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Loading/Error/Empty States
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading rankings...")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(AppColors.accentWarm)
            
            Text("Failed to Load")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Try Again") {
                Task { await loadLeaderboard() }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(AppColors.primary)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary)
            
            Text("No Rankings Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Complete a workout and share it to a club to appear on the leaderboard!")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadLeaderboard() async {
        isLoading = true
        errorMessage = nil
        isSignedOut = false
        
        do {
            entries = try await communityService.fetchGlobalLeaderboard(type: selectedType)
        } catch {
            if case CommunityError.notAuthenticated = error {
                isSignedOut = true
            } else {
                errorMessage = error.localizedDescription
                print("❌ Failed to load global leaderboard: \(error)")
            }
        }
        
        isLoading = false
    }
}

// MARK: - Leaderboard Type Capsule

struct LeaderboardTypeCapsule: View {
    let type: GlobalLeaderboardType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: type.iconName)
                    .font(.system(size: 14))
                
                Text(type.shortName)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? AppColors.textOnLight : AppColors.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? AppColors.primary : AppColors.primary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Leaderboard Row

struct GlobalLeaderboardRow: View {
    let entry: GlobalLeaderboardEntry
    let type: GlobalLeaderboardType
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                if entry.rank <= 3 {
                    Image(systemName: rankIcon)
                        .font(.system(size: 18))
                        .foregroundColor(rankColor)
                } else {
                    Text("\(entry.rank)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(rankColor)
                }
            }
            
            // Avatar
            if let avatarUrl = entry.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    avatarPlaceholder
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
            
            // Username with PRO crown
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.username)
                        .font(.system(size: 16, weight: isCurrentUser ? .bold : .semibold))
                        .foregroundColor(isCurrentUser ? AppColors.primary : AppColors.textPrimary)
                    
                    // PRO Crown for premium users
                    if entry.isPremium {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.yellow)
                    }
                }
                
                if isCurrentUser {
                    Text("That's you!")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.primary)
                }
            }
            
            Spacer()
            
            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedScore)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.primary)
                
                Text(type.unit)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isCurrentUser ? AppColors.primary.opacity(0.05) : Color.clear)
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(AppColors.primary.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Text(entry.username.prefix(1).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.primary)
            )
    }
    
    private var formattedScore: String {
        switch type {
        case .distance, .tonnage:
            return String(format: "%.1f", entry.score)
        case .elevation:
            return String(format: "%.0f", entry.score)
        case .consistency:
            return "\(Int(entry.score))"
        }
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return Color.yellow // Gold
        case 2: return Color.gray // Silver
        case 3: return Color.orange // Bronze
        default: return AppColors.primary
        }
    }
    
    private var rankIcon: String {
        switch entry.rank {
        case 1: return "trophy.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "number"
        }
    }
}

// MARK: - Preview

#Preview {
    GlobalLeaderboardView()
        .environmentObject(PremiumManager.shared)
}
