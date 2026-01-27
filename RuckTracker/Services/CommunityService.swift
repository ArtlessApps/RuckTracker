//
//  CommunityService.swift
//  MARCH
//
//  Handles all Supabase community operations:
//  - User profiles
//  - Clubs (create, join, leave)
//  - Activity feed (post workouts, view feed)
//  - Leaderboards (weekly rankings)
//  - Social interactions (likes)
//

import Foundation
import Supabase

/// Main service for all community features
@MainActor
class CommunityService: ObservableObject {
    static let shared = CommunityService()
    
    // MARK: - Published State
    
    @Published var currentProfile: UserProfile?
    @Published var myClubs: [Club] = []
    @Published var clubFeed: [ClubPost] = []
    @Published var weeklyLeaderboard: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Supabase Client
    
    // TODO: Replace with your actual Supabase URL and anon key
    private let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://myqlnifrvmhetsghwrpm.supabase.co")!,
        supabaseKey: "sb_publishable_g7C7bFmxE77NOpeWikCQnw_0zI43Paw"
    )
    
    // MARK: - Initialization
    
    private init() {
        // Check for existing session on init
        Task {
            await restoreSessionIfNeeded()
        }
    }
    
    /// Check for existing auth session and load user data
    func restoreSessionIfNeeded() async {
        // Supabase automatically persists sessions - check if we have one
        guard supabase.auth.currentUser != nil else {
            print("ℹ️ No existing session found")
            return
        }
        
        do {
            try await loadCurrentProfile()
            try await loadMyClubs()
            print("✅ Session restored with \(myClubs.count) clubs")
        } catch {
            print("❌ Failed to restore session data: \(error)")
            // Session might be expired, clear local state
            currentProfile = nil
            myClubs = []
        }
    }
    
    // MARK: - Authentication & Profile
    
    /// Sign up a new user with email/password
    func signUp(email: String, password: String, username: String, displayName: String) async throws {
        do {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

            // Create auth user
            let response = try await supabase.auth.signUp(
                email: normalizedEmail,
                password: password,
                data: [
                    "username": .string(trimmedUsername),
                    "display_name": .string(trimmedDisplayName)
                ]
            )
            
            // Profile is auto-created via database trigger
            print("✅ User created: \(response.user.id)")

            // Supabase can be configured to require email confirmation.
            // In that mode, signUp returns a user but NO session, so `currentUser` is nil until they confirm + sign in.
            guard response.session != nil else {
                throw CommunityError.emailConfirmationRequired
            }

            // Load the new profile (session exists => authenticated)
            try await loadCurrentProfile()
            
        } catch {
            print("❌ Sign up failed: \(error)")
            if let communityError = error as? CommunityError {
                throw communityError
            }
            throw CommunityError.authenticationFailed(error.localizedDescription)
        }
    }
    
    /// Sign in existing user
    func signIn(email: String, password: String) async throws {
        do {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let response = try await supabase.auth.signIn(
                email: normalizedEmail,
                password: password
            )
            
            print("✅ User signed in: \(response.user.id)")
            
            // Load their profile
            try await loadCurrentProfile()
            
            // Load their clubs
            try await loadMyClubs()
            
        } catch {
            print("❌ Sign in failed: \(error)")
            throw CommunityError.authenticationFailed(error.localizedDescription)
        }
    }
    
    /// Sign out current user
    func signOut() async throws {
        try await supabase.auth.signOut()
        
        // Clear local state
        currentProfile = nil
        myClubs = []
        clubFeed = []
        weeklyLeaderboard = []
        
        print("✅ User signed out")
    }
    
    /// Load the current user's profile
    func loadCurrentProfile() async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        let response: UserProfile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        
        currentProfile = response
        print("✅ Loaded profile: \(response.username)")
    }
    
    // MARK: - Clubs
    
    /// Create a new club
    func createClub(name: String, description: String) async throws -> Club {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        // Generate a simple join code (you can make this fancier)
        let joinCode = generateJoinCode(from: name)
        
        let clubData: [String: AnyJSON] = [
            "name": .string(name),
            "description": .string(description),
            "join_code": .string(joinCode),
            "created_by": .string(userId.uuidString)
        ]
        
        let newClub: Club = try await supabase
            .from("clubs")
            .insert(clubData)
            .select()
            .single()
            .execute()
            .value
        
        // Auto-join creator as admin
        try await joinClub(clubId: newClub.id, role: "admin")
        
        print("✅ Created club: \(newClub.name) with code: \(joinCode)")
        return newClub
    }
    
    /// Join a club using join code
    func joinClubWithCode(_ code: String) async throws {
        // Find club by join code
        let club: Club = try await supabase
            .from("clubs")
            .select()
            .eq("join_code", value: code.uppercased())
            .single()
            .execute()
            .value
        
        try await joinClub(clubId: club.id)
        print("✅ Joined club: \(club.name)")
    }
    
    /// Join a club by ID
    private func joinClub(clubId: UUID, role: String = "member") async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        // Check if user is already a member
        let existingMembers: [ClubMember] = try await supabase
            .from("club_members")
            .select()
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        if !existingMembers.isEmpty {
            throw CommunityError.alreadyMember
        }
        
        let memberData: [String: AnyJSON] = [
            "club_id": .string(clubId.uuidString),
            "user_id": .string(userId.uuidString),
            "role": .string(role)
        ]
        
        try await supabase
            .from("club_members")
            .insert(memberData)
            .execute()
        
        // Reload clubs
        try await loadMyClubs()
    }
    
    /// Leave a club
    func leaveClub(clubId: UUID) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        try await supabase
            .from("club_members")
            .delete()
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        // Reload clubs
        try await loadMyClubs()
        print("✅ Left club")
    }
    
    /// Load all clubs the user is a member of
    func loadMyClubs() async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        // Query clubs where user is a member
        let clubs: [Club] = try await supabase
            .from("clubs")
            .select("""
                *,
                club_members!inner(user_id)
            """)
            .eq("club_members.user_id", value: userId.uuidString)
            .execute()
            .value
        
        myClubs = clubs
        print("✅ Loaded \(clubs.count) clubs")
    }
    
    // MARK: - Activity Feed
    
    /// Post a workout to a club feed
    func postWorkout(
        clubId: UUID,
        distance: Double,
        duration: Int,
        weight: Double,
        calories: Int,
        caption: String? = nil,
        workoutId: UUID
    ) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        var postData: [String: AnyJSON] = [
            "club_id": .string(clubId.uuidString),
            "user_id": .string(userId.uuidString),
            "post_type": .string("workout"),
            "workout_id": .string(workoutId.uuidString),
            "distance_miles": .double(distance),
            "duration_minutes": .double(Double(duration)),
            "weight_lbs": .double(weight),
            "calories": .double(Double(calories))
        ]
        
        if let caption = caption {
            postData["content"] = .string(caption)
        }
        
        try await supabase
            .from("club_posts")
            .insert(postData)
            .execute()
        
        // Also update leaderboard
        try await updateLeaderboard(clubId: clubId, distance: distance, weight: weight)
        
        print("✅ Posted workout to club feed")
    }
    
    /// Load feed for a specific club using RPC (bypasses RLS issues)
    func loadClubFeed(clubId: UUID, limit: Int = 50) async throws {
        print("🔍 Loading club feed for clubId: \(clubId.uuidString)")
        
        do {
            let feedItems: [ClubFeedItem] = try await supabase
                .rpc(
                    "get_club_feed",
                    params: GetClubFeedParams(p_club_id: clubId, p_limit: limit)
                )
                .execute()
                .value
            
            // Convert flat feed items to ClubPost format
            clubFeed = feedItems.map { item in
                ClubPost(
                    id: item.id,
                    clubId: item.clubId,
                    userId: item.userId,
                    postType: item.postType,
                    content: item.content,
                    workoutId: item.workoutId,
                    distanceMiles: item.distanceMiles,
                    durationMinutes: item.durationMinutes,
                    weightLbs: item.weightLbs,
                    calories: item.calories,
                    likeCount: item.likeCount,
                    commentCount: item.commentCount,
                    createdAt: item.createdAt,
                    author: item.authorId != nil ? PostAuthor(
                        id: item.authorId!,
                        username: item.authorUsername ?? "unknown",
                        displayName: item.authorDisplayName ?? "Unknown",
                        avatarUrl: item.authorAvatarUrl,
                        createdAt: item.createdAt
                    ) : nil
                )
            }
            
            print("✅ Loaded \(clubFeed.count) posts for club \(clubId)")
        } catch {
            print("❌ Failed to load club feed: \(error)")
            print("❌ Error details: \(String(describing: error))")
            throw error
        }
    }
    
    /// Like a post
    func likePost(postId: UUID) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        let likeData: [String: AnyJSON] = [
            "post_id": .string(postId.uuidString),
            "user_id": .string(userId.uuidString)
        ]
        
        try await supabase
            .from("post_likes")
            .insert(likeData)
            .execute()
        
        print("✅ Liked post")
    }
    
    /// Unlike a post
    func unlikePost(postId: UUID) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        try await supabase
            .from("post_likes")
            .delete()
            .eq("post_id", value: postId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        print("✅ Unliked post")
    }
    
    // MARK: - Leaderboards
    
    private struct UpdateLeaderboardParams: Encodable {
        let p_club_id: UUID
        let p_user_id: UUID
        let p_distance: Double
        let p_weight: Double
    }
    
    private struct GetWeeklyLeaderboardParams: Encodable {
        let p_club_id: UUID
    }
    
    private struct GetClubFeedParams: Encodable {
        let p_club_id: UUID
        let p_limit: Int
    }
    
    /// Update user's weekly leaderboard entry after a workout
    private func updateLeaderboard(clubId: UUID, distance: Double, weight: Double) async throws {
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        // Call the database function
        try await supabase
            .rpc(
                "update_leaderboard_entry",
                params: UpdateLeaderboardParams(
                    p_club_id: clubId,
                    p_user_id: userId,
                    p_distance: distance,
                    p_weight: weight
                )
            )
            .execute()
        
        print("✅ Updated leaderboard")
    }
    
    /// Load weekly leaderboard for a club
    func loadWeeklyLeaderboard(clubId: UUID) async throws {
        let entries: [LeaderboardEntry] = try await supabase
            .rpc(
                "get_weekly_leaderboard",
                params: GetWeeklyLeaderboardParams(p_club_id: clubId)
            )
            .execute()
            .value
        
        weeklyLeaderboard = entries
        print("✅ Loaded leaderboard: \(entries.count) entries")
    }
    
    // MARK: - Helper Functions
    
    private func generateJoinCode(from name: String) -> String {
        // Simple join code: first 2-3 letters + random number
        let prefix = String(name.prefix(3)).uppercased().replacingOccurrences(of: " ", with: "")
        let random = Int.random(in: 1000...9999)
        return "\(prefix)-\(random)"
    }
}

// MARK: - Models

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let location: String?
    let totalDistance: Double?
    let totalWorkouts: Int?
    let currentStreak: Int?
    let longestStreak: Int?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
        case location
        case totalDistance = "total_distance"
        case totalWorkouts = "total_workouts"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case createdAt = "created_at"
    }
}

struct Club: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let joinCode: String
    let createdBy: UUID?
    let isPrivate: Bool
    let avatarUrl: String?
    let memberCount: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case joinCode = "join_code"
        case createdBy = "created_by"
        case isPrivate = "is_private"
        case avatarUrl = "avatar_url"
        case memberCount = "member_count"
        case createdAt = "created_at"
    }
}

struct ClubMember: Codable {
    let clubId: UUID
    let userId: UUID
    let role: String
    let joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}

/// Lightweight profile for joined post data
struct PostAuthor: Codable {
    let id: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

struct ClubPost: Codable, Identifiable {
    let id: UUID
    let clubId: UUID
    let userId: UUID
    let postType: String
    let content: String?
    let workoutId: UUID?
    let distanceMiles: Double?
    let durationMinutes: Int?
    let weightLbs: Double?
    let calories: Int?
    let likeCount: Int
    let commentCount: Int
    let createdAt: Date
    
    // Joined profile data
    let author: PostAuthor?
    
    enum CodingKeys: String, CodingKey {
        case id
        case clubId = "club_id"
        case userId = "user_id"
        case postType = "post_type"
        case content
        case workoutId = "workout_id"
        case distanceMiles = "distance_miles"
        case durationMinutes = "duration_minutes"
        case weightLbs = "weight_lbs"
        case calories
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case author = "profiles"
    }
}

/// Flat structure returned by get_club_feed RPC function
struct ClubFeedItem: Codable {
    let id: UUID
    let clubId: UUID
    let userId: UUID
    let postType: String
    let content: String?
    let workoutId: UUID?
    let distanceMiles: Double?
    let durationMinutes: Int?
    let weightLbs: Double?
    let calories: Int?
    let likeCount: Int
    let commentCount: Int
    let createdAt: Date
    let authorId: UUID?
    let authorUsername: String?
    let authorDisplayName: String?
    let authorAvatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case clubId = "club_id"
        case userId = "user_id"
        case postType = "post_type"
        case content
        case workoutId = "workout_id"
        case distanceMiles = "distance_miles"
        case durationMinutes = "duration_minutes"
        case weightLbs = "weight_lbs"
        case calories
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case authorId = "author_id"
        case authorUsername = "author_username"
        case authorDisplayName = "author_display_name"
        case authorAvatarUrl = "author_avatar_url"
    }
}

struct LeaderboardEntry: Codable, Identifiable {
    let id = UUID() // Computed, not from DB
    let rank: Int
    let userId: UUID
    let username: String
    let displayName: String
    let avatarUrl: String?
    let totalDistance: Double
    let totalWorkouts: Int
    
    enum CodingKeys: String, CodingKey {
        case rank
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case totalDistance = "total_distance"
        case totalWorkouts = "total_workouts"
    }
}

// MARK: - Errors

enum CommunityError: Error, LocalizedError {
    case notAuthenticated
    case authenticationFailed(String)
    case emailConfirmationRequired
    case networkError(String)
    case invalidData
    case alreadyMember
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .emailConfirmationRequired:
            return "Account created. Please check your email to confirm your account, then sign in."
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidData:
            return "Invalid data received from server"
        case .alreadyMember:
            return "You're already a member of this club"
        }
    }
}

