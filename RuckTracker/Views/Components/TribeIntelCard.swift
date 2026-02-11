import SwiftUI

// MARK: - Tribe Intel Card
/// The bottom card on the Dashboard. Surfaces the single most relevant piece
/// of community activity using a priority system:
///   1. Upcoming event (within 48 h)
///   2. Active challenge progress
///   3. Fallback tribe status
struct TribeIntelCard: View {
    // MARK: - Services
    @StateObject private var communityService = CommunityService.shared
    @ObservedObject private var challengeService = LocalChallengeService.shared
    
    // MARK: - State
    @State private var upcomingEvent: ClubEvent?
    @State private var primaryClub: Club?
    @State private var weeklyTribeWeight: Double = 0
    @State private var hasLoadedData = false
    
    // MARK: - Actions
    let onViewEvent: ((ClubEvent) -> Void)?
    let onViewChallenge: (() -> Void)?
    let onViewTribe: (() -> Void)?
    
    init(
        onViewEvent: ((ClubEvent) -> Void)? = nil,
        onViewChallenge: (() -> Void)? = nil,
        onViewTribe: (() -> Void)? = nil
    ) {
        self.onViewEvent = onViewEvent
        self.onViewChallenge = onViewChallenge
        self.onViewTribe = onViewTribe
    }
    
    // MARK: - Computed Priority
    
    private enum IntelPriority {
        case upcomingEvent(ClubEvent)
        case activeChallenge(challenge: Challenge, progress: ChallengeProgress)
        case tribeStatus(club: Club, weeklyWeight: Double)
        case noTribe
    }
    
    private var currentPriority: IntelPriority {
        // Priority 1: Upcoming event in the next 48 hours
        if let event = upcomingEvent {
            return .upcomingEvent(event)
        }
        
        // Priority 2: Active challenge
        if let challenge = challengeService.enrolledChallenge,
           let progress = challengeService.challengeProgress {
            return .activeChallenge(challenge: challenge, progress: progress)
        }
        
        // Priority 3: Tribe status
        if let club = primaryClub {
            return .tribeStatus(club: club, weeklyWeight: weeklyTribeWeight)
        }
        
        // No tribe at all
        return .noTribe
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            switch currentPriority {
            case .upcomingEvent(let event):
                eventContent(event)
            case .activeChallenge(let challenge, let progress):
                challengeContent(challenge: challenge, progress: progress)
            case .tribeStatus(let club, let weight):
                tribeStatusContent(club: club, weeklyWeight: weight)
            case .noTribe:
                noTribeContent
            }
        }
        .onAppear {
            if !hasLoadedData {
                loadTribeData()
            }
        }
    }
    
    // MARK: - Priority 1: Upcoming Event
    
    private func eventContent(_ event: ClubEvent) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                cardIcon(systemName: "calendar.badge.clock", color: AppColors.accentWarm)
                
                Text("UPCOMING EVENT")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.accentWarm)
                
                Spacer()
                
                Text(timeUntilString(event.startTime))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.bottom, 12)
            
            // Event title
            Text(event.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .padding(.bottom, 4)
            
            // Event time
            HStack(spacing: 12) {
                Label(eventDateString(event.startTime), systemImage: "clock")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                
                if let address = event.addressText, !address.isEmpty {
                    Label(address, systemImage: "mappin")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 16)
            
            // Action button
            Button {
                onViewEvent?(event)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("VIEW DETAILS")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                .foregroundColor(AppColors.accentWarm)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.accentWarm.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.accentWarm.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(cardBackground(accent: AppColors.accentWarm))
    }
    
    // MARK: - Priority 2: Active Challenge
    
    private func challengeContent(challenge: Challenge, progress: ChallengeProgress) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                cardIcon(systemName: "trophy.fill", color: AppColors.primary)
                
                Text("ACTIVE CHALLENGE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.primary)
                
                Spacer()
                
                Text("Day \(progress.currentDay)/\(progress.total)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.bottom, 12)
            
            // Challenge title
            Text(challenge.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .padding(.bottom, 8)
            
            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.textSecondary.opacity(0.15))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.primaryGradient)
                            .frame(
                                width: geometry.size.width * min(CGFloat(progress.completionPercentage) / 100.0, 1.0),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Text("\(progress.completed) of \(progress.total) workouts completed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    Text("\(Int(progress.completionPercentage))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(.bottom, 16)
            
            // Action button
            Button {
                onViewChallenge?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("VIEW CHALLENGE")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                .foregroundColor(AppColors.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.primary.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(cardBackground(accent: AppColors.primary))
    }
    
    // MARK: - Priority 3: Tribe Status
    
    private func tribeStatusContent(club: Club, weeklyWeight: Double) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                cardIcon(systemName: "person.3.fill", color: AppColors.accentGreen)
                
                Text("TRIBE STATUS")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.accentGreen)
                
                Spacer()
                
                Text(club.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            .padding(.bottom, 12)
            
            // Stats
            HStack(spacing: 0) {
                // Weekly weight
                VStack(spacing: 4) {
                    Text(formattedWeight(weeklyWeight))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("lbs moved this week")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                
                // Divider
                Rectangle()
                    .fill(AppColors.textSecondary.opacity(0.15))
                    .frame(width: 1, height: 40)
                
                // Members
                VStack(spacing: 4) {
                    Text("\(club.memberCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("members")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 16)
            
            // Action button
            Button {
                onViewTribe?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("VIEW TRIBE")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                .foregroundColor(AppColors.accentGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.accentGreen.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.accentGreen.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(cardBackground(accent: AppColors.accentGreen))
    }
    
    // MARK: - No Tribe Fallback
    
    private var noTribeContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                cardIcon(systemName: "person.3.fill", color: AppColors.textSecondary)
                
                Text("TRIBE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
            }
            .padding(.bottom, 12)
            
            // CTA
            Text("Join a Tribe")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            
            Text("Coordinate rucks, events, and challenges with your crew.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)
            
            // Action button
            Button {
                onViewTribe?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("FIND A TRIBE")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.textSecondary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.textSecondary.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(cardBackground(accent: AppColors.textSecondary))
    }
    
    // MARK: - Shared Components
    
    private func cardIcon(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
    }
    
    private func cardBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(accent.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 6)
    }
    
    // MARK: - Data Loading
    
    private func loadTribeData() {
        hasLoadedData = true
        
        // Get user's primary club (first club)
        let clubs = communityService.myClubs
        primaryClub = clubs.first
        
        guard let club = primaryClub else {
            // If not loaded yet, try fetching
            Task {
                try? await communityService.loadMyClubs()
                await MainActor.run {
                    primaryClub = communityService.myClubs.first
                    if let club = primaryClub {
                        loadEventsAndLeaderboard(for: club)
                    }
                }
            }
            return
        }
        
        loadEventsAndLeaderboard(for: club)
    }
    
    private func loadEventsAndLeaderboard(for club: Club) {
        Task {
            // Load events
            try? await communityService.loadClubEvents(clubId: club.id)
            
            // Load leaderboard for weekly weight
            try? await communityService.loadWeeklyLeaderboard(clubId: club.id)
            
            await MainActor.run {
                // Find events within 48 hours
                let cutoff = Date().addingTimeInterval(48 * 60 * 60)
                upcomingEvent = communityService.clubEvents
                    .filter { $0.startTime > Date() && $0.startTime <= cutoff }
                    .sorted { $0.startTime < $1.startTime }
                    .first
                
                // Sum weekly weight from leaderboard
                weeklyTribeWeight = communityService.weeklyLeaderboard
                    .reduce(0) { $0 + $1.totalDistance } // distance in leaderboard is the metric
            }
        }
    }
    
    // MARK: - Formatters
    
    private func timeUntilString(_ date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        if interval < 3600 {
            return "in \(Int(interval / 60))m"
        } else if interval < 86400 {
            return "in \(Int(interval / 3600))h"
        } else {
            let days = Int(interval / 86400)
            let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
            return "in \(days)d \(hours)h"
        }
    }
    
    private func eventDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
    
    private func formattedWeight(_ weight: Double) -> String {
        if weight >= 1000 {
            return String(format: "%.1fK", weight / 1000)
        }
        return "\(Int(weight))"
    }
}

// MARK: - Previews

#Preview("Upcoming Event") {
    ZStack {
        AppColors.backgroundGradient
            .ignoresSafeArea()
        
        TribeIntelCard()
            .padding(.horizontal, 20)
    }
    .preferredColorScheme(.dark)
}
