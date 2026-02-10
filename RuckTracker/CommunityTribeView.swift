//
//  CommunityTribeView.swift
//  MARCH
//
//  New TRIBE tab with:
//  - My Clubs list
//  - Club activity feed
//  - Weekly leaderboards
//  - Join/create club flows
//

import SwiftUI

// MARK: - Main TRIBE Tab View

struct CommunityTribeView: View {
    @StateObject private var communityService = CommunityService.shared
    @State private var selectedClub: Club?
    @State private var showingJoinClub = false
    @State private var showingCreateClub = false
    @State private var showingAuth = false
    
    var body: some View {
        NavigationView {
            Group {
                if communityService.currentProfile == nil {
                    // Not signed in - show sign in prompt
                    authPromptView
                } else if communityService.myClubs.isEmpty {
                    // Signed in but no clubs - show onboarding
                    emptyClubsView
                } else {
                    // Has clubs - show list
                    clubsListView
                }
            }
            .navigationTitle("Tribe")
            .sheet(isPresented: $showingAuth) {
                AuthenticationView()
            }
            .sheet(isPresented: $showingJoinClub) {
                JoinClubView()
            }
            .sheet(isPresented: $showingCreateClub) {
                CreateClubView()
            }
            .sheet(item: $selectedClub) { club in
                ClubDetailView(club: club)
            }
        }
        .task(id: communityService.currentProfile?.id) {
            // Load clubs when profile becomes available
            if communityService.currentProfile != nil && communityService.myClubs.isEmpty {
                try? await communityService.loadMyClubs()
            }
        }
    }
    
    // MARK: - Auth Prompt
    
    private var authPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 64))
                .foregroundColor(AppColors.primary)
            
            Text("Join the MARCH Community")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Connect with ruckers worldwide, share your workouts, and compete on weekly leaderboards.")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: { showingAuth = true }) {
                Text("Sign In or Create Account")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textOnLight)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Empty Clubs
    
    private var emptyClubsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.hiking")
                .font(.system(size: 64))
                .foregroundColor(AppColors.primary)
            
            Text("Join Your First Club")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Clubs are communities of ruckers training together. Join one to share workouts and compete on leaderboards.")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            VStack(spacing: 12) {
                Button(action: { showingJoinClub = true }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Join a Club")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textOnLight)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primary)
                    .cornerRadius(12)
                }
                
                Button(action: { showingCreateClub = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Create a Club")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Clubs List
    
    private var clubsListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(communityService.myClubs) { club in
                    Button(action: { selectedClub = club }) {
                        ClubCard(club: club)
                    }
                    .buttonStyle(.plain)
                }
                
                // Action buttons - always visible below clubs
                HStack(spacing: 12) {
                    Button(action: { showingJoinClub = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 14))
                            Text("Join Club")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.primary, lineWidth: 1.5)
                        )
                    }
                    
                    Button(action: { showingCreateClub = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 14))
                            Text("Create Club")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.primary, lineWidth: 1.5)
                        )
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }
}

// MARK: - Club Card Component

struct ClubCard: View {
    let club: Club
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Club avatar or icon
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(club.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("\(club.memberCount) members")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary)
            }
            
            if let description = club.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Club Detail View

struct ClubDetailView: View {
    let club: Club
    @StateObject private var communityService = CommunityService.shared
    @State private var selectedTab: ClubTab = .events
    @State private var userRole: ClubRole = .member
    @State private var showingMembers = false
    @State private var showingLeaveConfirmation = false
    @State private var showingSettings = false
    @State private var showingShareInvite = false
    @State private var isLeaving = false
    @State private var currentClub: Club
    @Environment(\.dismiss) private var dismiss
    
    enum ClubTab: String, CaseIterable {
        case events = "Events"
        case feed = "Feed"
        case leaderboard = "Leaderboard"
    }
    
    init(club: Club) {
        self.club = club
        self._currentClub = State(initialValue: club)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab picker
                Picker("View", selection: $selectedTab) {
                    ForEach(ClubTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on tab
                switch selectedTab {
                case .events:
                    EventListView(club: currentClub, userRole: userRole)
                case .feed:
                    ClubFeedView(club: currentClub)
                case .leaderboard:
                    ClubLeaderboardView(club: currentClub)
                }
            }
            .navigationTitle(currentClub.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingMembers = true }) {
                        Image(systemName: "person.2")
                    }
                    .foregroundColor(AppColors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Club settings menu
                        Menu {
                            // Founder-only: Settings
                            if userRole == .founder {
                                Button(action: { showingSettings = true }) {
                                    Label("Club Settings", systemImage: "gearshape")
                                }
                            }
                            
                            // Founder/Leader: Share invite and copy join code
                            if userRole.canInviteMembers {
                                Button(action: { showingShareInvite = true }) {
                                    Label("Invite Members", systemImage: "person.badge.plus")
                                }
                                
                                Button(action: copyJoinCode) {
                                    Label("Copy Join Code", systemImage: "doc.on.doc")
                                }
                            }
                            
                            Divider()
                            
                            // Leave club (not for founders)
                            if userRole != .founder {
                                Button(role: .destructive, action: { showingLeaveConfirmation = true }) {
                                    Label("Leave Club", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(AppColors.primary)
                        }
                        
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingMembers) {
                ClubMembersView(club: currentClub, userRole: userRole)
            }
            .sheet(isPresented: $showingSettings, onDismiss: refreshClubData) {
                ClubSettingsView(club: currentClub)
            }
            .sheet(isPresented: $showingShareInvite) {
                ShareInviteSheet(club: currentClub, joinCode: currentClub.joinCode)
            }
            .alert("Leave Club", isPresented: $showingLeaveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    leaveClub()
                }
            } message: {
                Text("Are you sure you want to leave \(currentClub.name)? You'll need to rejoin with the club code to access it again.")
            }
        }
        .task(id: club.id) {
            // Reset role until we load (avoids showing previous club's role when sheet item changes)
            userRole = .member
            // Load user role for this specific club (founder only in clubs they founded)
            do {
                userRole = try await communityService.getUserRole(clubId: club.id)
                print("✅ User role: \(userRole.displayText) for club \(club.name)")
            } catch {
                print("❌ Failed to get user role: \(error)")
            }
            
            // Load feed and leaderboard when view appears
            do {
                try await communityService.loadClubFeed(clubId: club.id)
                print("✅ Club feed loaded successfully")
            } catch {
                print("❌ ClubDetailView: Failed to load feed: \(error)")
            }
            
            do {
                try await communityService.loadWeeklyLeaderboard(clubId: club.id)
                print("✅ Leaderboard loaded successfully")
            } catch {
                print("❌ ClubDetailView: Failed to load leaderboard: \(error)")
            }
        }
    }
    
    private func copyJoinCode() {
        UIPasteboard.general.string = currentClub.joinCode
    }
    
    private func refreshClubData() {
        Task {
            do {
                // Refresh club data after settings changes
                let updatedClub = try await communityService.getClub(clubId: club.id)
                currentClub = updatedClub
                
                // Also refresh role in case ownership was transferred
                userRole = try await communityService.getUserRole(clubId: club.id)
            } catch {
                // Club may have been deleted, dismiss if so
                if communityService.myClubs.first(where: { $0.id == club.id }) == nil {
                    dismiss()
                }
                print("❌ Failed to refresh club: \(error)")
            }
        }
    }
    
    // MARK: - Leave Club
    
    private func leaveClub() {
        isLeaving = true
        Task {
            do {
                try await communityService.leaveClub(clubId: club.id)
                dismiss()
            } catch {
                print("❌ Failed to leave club: \(error)")
                isLeaving = false
            }
        }
    }
}

// MARK: - Club Feed View

struct ClubFeedView: View {
    let club: Club
    @StateObject private var communityService = CommunityService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if communityService.clubFeed.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text("No activity yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Complete a workout to share it with your club!")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 64)
                } else {
                    ForEach(communityService.clubFeed) { post in
                        FeedPostCard(post: post)
                    }
                }
            }
            .padding()
        }
        .background(AppColors.backgroundGradient)
    }
}

// MARK: - Feed Post Card

struct FeedPostCard: View {
    let post: ClubPost
    @StateObject private var communityService = CommunityService.shared
    @State private var isLiked = false
    @State private var likeCount: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: user info
            HStack(spacing: 12) {
                Circle()
                    .fill(AppColors.primary.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(post.author?.username.prefix(1).uppercased() ?? "?")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author?.username ?? "Unknown")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(post.createdAt.timeAgoDisplay())
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            
            // Workout stats
            if post.postType == "workout" {
                HStack(spacing: 12) {
                    IconStatPill(icon: "figure.walk", value: String(format: "%.1f mi", post.distanceMiles ?? 0))
                    IconStatPill(icon: "clock", value: "\(post.durationMinutes ?? 0) min")
                    if let elevation = post.elevationGain, elevation > 0 {
                        IconStatPill(icon: "arrow.up.right", value: "\(Int(elevation)) ft")
                    }
                    if let weight = post.weightLbs, weight > 0 {
                        IconStatPill(icon: "scalemass", value: "\(Int(weight)) lbs")
                    }
                }
            }
            
            // Caption
            if let content = post.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            // Actions
            HStack(spacing: 24) {
                Button(action: { toggleLike() }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? AppColors.accentWarm : AppColors.textSecondary)
                        Text("\(likeCount)")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                // Comment button (future)
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(AppColors.textSecondary)
                    Text("\(post.commentCount)")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 1)
        )
        .onAppear {
            likeCount = post.likeCount
        }
    }
    
    private func toggleLike() {
        // Optimistic UI update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        Task {
            do {
                if isLiked {
                    try await communityService.likePost(postId: post.id)
                } else {
                    try await communityService.unlikePost(postId: post.id)
                }
            } catch {
                // Revert on error
                isLiked.toggle()
                likeCount += isLiked ? 1 : -1
                print("❌ Failed to toggle like: \(error)")
            }
        }
    }
}

struct IconStatPill: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(AppColors.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppColors.primary.opacity(0.1))
        )
    }
}

// MARK: - Club Leaderboard View

struct ClubLeaderboardView: View {
    let club: Club
    @StateObject private var communityService = CommunityService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("This Week")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("Weekly Distance")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // Leaderboard entries
                if communityService.weeklyLeaderboard.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "trophy")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text("No activity this week")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Complete a workout to appear on the leaderboard!")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 64)
                } else {
                    VStack(spacing: 1) {
                        ForEach(communityService.weeklyLeaderboard) { entry in
                            LeaderboardRow(entry: entry)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppColors.backgroundGradient)
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Text("\(entry.rank)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(rankColor)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text("\(entry.totalWorkouts) workouts")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            // Stats: Distance and Elevation
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f mi", entry.totalDistance))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.primary)
                
                if entry.totalElevation > 0 {
                    Text("↑\(Int(entry.totalElevation)) ft")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(AppColors.surface)
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return AppColors.accentWarm // Gold/orange for 1st
        case 2: return AppColors.textSecondary // Silver/gray for 2nd
        case 3: return AppColors.accentTeal // Bronze/teal for 3rd
        default: return AppColors.primary
        }
    }
}

// MARK: - Join Club View

struct JoinClubView: View {
    @StateObject private var communityService = CommunityService.shared
    @State private var selectedTab: JoinClubTab = .code
    @State private var joinCode = ""
    @State private var searchZipcode = ""
    @State private var isJoining = false
    @State private var isSearching = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    // Waiver sheet state
    @State private var showingWaiverSheet = false
    @State private var pendingClubId: UUID?
    @State private var pendingClubName: String = ""
    
    enum JoinClubTab: String, CaseIterable {
        case code = "Enter Code"
        case find = "Find a Club"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab picker
                    Picker("Join Method", selection: $selectedTab) {
                        ForEach(JoinClubTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    switch selectedTab {
                    case .code:
                        joinWithCodeView
                    case .find:
                        findClubView
                    }
                }
            }
            .navigationTitle("Join a Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .sheet(isPresented: $showingWaiverSheet) {
                if let clubId = pendingClubId {
                    WaiverOnboardingSheet(
                        clubId: clubId,
                        clubName: pendingClubName,
                        onWaiverSigned: {
                            completeJoin()
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Join with Code View
    
    private var joinWithCodeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(AppColors.primary)
            
            Text("Have a Code?")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Enter the club code shared by your group admin")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            TextField("Club Code (e.g., SD-1234)", text: $joinCode)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .padding(.horizontal, 32)
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accentWarm)
            }
            
            Button(action: { joinClubWithCode() }) {
                if isJoining {
                    ProgressView()
                        .tint(AppColors.textOnLight)
                } else {
                    Text("Join Club")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(joinCode.isEmpty || isJoining)
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.top, 32)
    }
    
    // MARK: - Find Club View
    
    private var findClubView: some View {
        VStack(spacing: 16) {
            // Search by zipcode
            HStack(spacing: 12) {
                TextField("Enter zipcode", text: $searchZipcode)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                
                Button(action: { searchClubs() }) {
                    if isSearching {
                        ProgressView()
                            .tint(AppColors.primary)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(width: 44, height: 44)
                .background(AppColors.primary)
                .foregroundColor(AppColors.textOnLight)
                .cornerRadius(8)
                .disabled(isSearching)
            }
            .padding(.horizontal)
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accentWarm)
                    .padding(.horizontal)
            }
            
            // Results
            if communityService.nearbyClubs.isEmpty && !isSearching {
                VStack(spacing: 16) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("Find Clubs Near You")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Enter your zipcode to discover public clubs in your area")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 48)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(communityService.nearbyClubs) { club in
                            NearbyClubCard(club: club, onJoin: {
                                joinDiscoveredClub(club)
                            }, isJoining: isJoining)
                        }
                    }
                    .padding()
                }
            }
            
            Spacer()
        }
        .padding(.top)
    }
    
    // MARK: - Actions
    
    private func joinClubWithCode() {
        isJoining = true
        errorMessage = nil
        
        Task {
            do {
                let club = try await communityService.getClubByCode(joinCode)
                // Join first (insert row) so signWaiver can update it; then show waiver sheet
                try await communityService.joinClubById(club.id)
                pendingClubId = club.id
                pendingClubName = club.name
                showingWaiverSheet = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isJoining = false
        }
    }
    
    /// Called after user signs the waiver; we already joined in the previous step, so just dismiss and refresh.
    private func completeJoin() {
        Task {
            try? await communityService.loadMyClubs()
        }
        dismiss()
    }
    
    private func searchClubs() {
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                if searchZipcode.isEmpty {
                    try await communityService.findPublicClubs()
                } else {
                    try await communityService.findNearbyClubs(zipcode: searchZipcode)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }
    
    private func joinDiscoveredClub(_ club: Club) {
        isJoining = true
        errorMessage = nil
        
        Task {
            do {
                // Join first (insert row) so signWaiver can update it; then show waiver sheet
                try await communityService.joinClubById(club.id)
                pendingClubId = club.id
                pendingClubName = club.name
                showingWaiverSheet = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isJoining = false
        }
    }
}

// MARK: - Nearby Club Card

struct NearbyClubCard: View {
    let club: Club
    let onJoin: () -> Void
    let isJoining: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Club avatar or icon
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(club.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    HStack(spacing: 8) {
                        Text("\(club.memberCount) members")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                        
                        if let zipcode = club.zipcode {
                            Text("•")
                                .foregroundColor(AppColors.textSecondary)
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 12))
                                Text(zipcode)
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            if let description = club.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }
            
            Button(action: onJoin) {
                if isJoining {
                    ProgressView()
                        .tint(AppColors.textOnLight)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Join Club")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
            }
            .foregroundColor(AppColors.textOnLight)
            .padding(.vertical, 10)
            .background(AppColors.primary)
            .cornerRadius(8)
            .disabled(isJoining)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Create Club View

struct CreateClubView: View {
    @StateObject private var communityService = CommunityService.shared
    @State private var clubName = ""
    @State private var clubDescription = ""
    @State private var isPrivate = false
    @State private var customInviteCode = ""
    @State private var zipcode = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var createdClubCode: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Club Name")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                            
                            TextField("San Diego Ruckers", text: $clubName)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("Description (optional)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                            
                            TextEditor(text: $clubDescription)
                                .frame(height: 100)
                                .padding(8)
                                .background(AppColors.surface)
                                .cornerRadius(8)
                                .scrollContentBackground(.hidden)
                            
                            // Privacy toggle
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Private Club")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Text(isPrivate ? "Only visible with invite code" : "Visible in club search")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $isPrivate)
                                    .labelsHidden()
                                    .tint(AppColors.primary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.surface)
                            )
                            
                            // Custom invite code (shown when private)
                            if isPrivate {
                                Text("Custom Invite Code")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                TextField("e.g., MYCLUB-2024", text: $customInviteCode)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled(true)
                                
                                Text("Leave blank to auto-generate a code. Custom codes must be unique.")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            // Zipcode for discoverability
                            Text("Location (Zipcode)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                            
                            TextField("92101", text: $zipcode)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                            
                            Text("Helps nearby ruckers find your club")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding()
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(AppColors.accentWarm)
                                .font(.system(size: 14))
                        }
                        
                        Button(action: { createClub() }) {
                            if isCreating {
                                ProgressView()
                                    .tint(AppColors.textOnLight)
                            } else {
                                Text("Create Club")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(clubName.isEmpty || isCreating)
                        .padding(.horizontal)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Create Club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
    
    private func createClub() {
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                // Trim and uppercase the custom code if provided
                let trimmedCode = customInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                
                let newClub = try await communityService.createClub(
                    name: clubName,
                    description: clubDescription,
                    isPrivate: isPrivate,
                    zipcode: zipcode.isEmpty ? nil : zipcode,
                    customJoinCode: trimmedCode.isEmpty ? nil : trimmedCode
                )
                
                // Show success message with join code
                print("✅ Created club with code: \(newClub.joinCode)")
                createdClubCode = newClub.joinCode
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
}

// MARK: - Authentication View

struct AuthenticationView: View {
    @StateObject private var communityService = CommunityService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    /// Optional callback for when login/signup is successful (used by onboarding to skip flow)
    var onLoginSuccess: (() -> Void)?
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Email")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField("your@email.com", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                        
                        Text("Password")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(isSignUp ? .newPassword : .password)
                        
                        if isSignUp {
                            Text("Username")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                            
                            TextField("Your name", text: $username)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                        }
                    }
                    .padding()
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(AppColors.accentWarm)
                            .font(.system(size: 14))
                            .padding(.horizontal)
                    }
                    
                    Button(action: { authenticate() }) {
                        if isLoading {
                            ProgressView()
                                .tint(AppColors.textOnLight)
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading || !isFormValid)
                    .padding(.horizontal)
                    
                    Button(action: { isSignUp.toggle() }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.primary)
                    }
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        if isSignUp {
            return isValidEmail(normalizedEmail)
                && !password.isEmpty
                && !trimmedUsername.isEmpty
        } else {
            return isValidEmail(normalizedEmail) && !password.isEmpty
        }
    }
    
    private func authenticate() {
        isLoading = true
        errorMessage = nil

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                if isSignUp {
                    try await communityService.signUp(
                        email: normalizedEmail,
                        password: password,
                        username: trimmedUsername
                    )
                } else {
                    try await communityService.signIn(email: normalizedEmail, password: password)
                }
                // Call the success callback before dismissing (if provided)
                onLoginSuccess?()
                dismiss()
            } catch {
                if let communityError = error as? CommunityError, case .emailConfirmationRequired = communityError {
                    // Treat this as a "next step" message, not a hard failure.
                    errorMessage = communityError.localizedDescription
                    isSignUp = false
                } else {
                    errorMessage = mapAuthError(error)
                }
                isLoading = false
            }
        }
    }

    private func mapAuthError(_ error: Error) -> String {
        let message = error.localizedDescription

        // Supabase/GoTrue often returns: `Email address "..." is invalid`
        if message.localizedCaseInsensitiveContains("email_address_invalid")
            || (message.localizedCaseInsensitiveContains("email address")
                && message.localizedCaseInsensitiveContains("invalid")) {
            return "Supabase rejected this email. For signup, use a real email address you can receive (avoid placeholder/test domains like example.com/test.com) and make sure there are no spaces."
        }

        return message
    }

    private func isValidEmail(_ email: String) -> Bool {
        // Simple sanity check (fast + avoids most false negatives caused by whitespace)
        // Not a full RFC validator by design.
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Helpers

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(AppColors.textOnLight)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppColors.primary)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

