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
import CoreLocation

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
    
    /// Returns true if there's an authenticated user session
    var isAuthenticated: Bool {
        supabase.auth.currentUser != nil
    }
    
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
    func signUp(email: String, password: String, username: String) async throws {
        do {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

            // Create auth user
            let response = try await supabase.auth.signUp(
                email: normalizedEmail,
                password: password,
                data: [
                    "username": .string(trimmedUsername)
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
            
            // Check for duplicate username error (PostgreSQL unique violation on username column)
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("duplicate") ||
               errorMessage.contains("23505") ||
               errorMessage.contains("unique") {
                if errorMessage.contains("username") || errorMessage.contains("profiles_username") {
                    throw CommunityError.duplicateUsername
                }
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
    
    /// Update the user's premium status in the database
    /// Called by PremiumManager when subscription status changes
    func updatePremiumStatus(isPremium: Bool) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        try await supabase
            .from("profiles")
            .update(["is_premium": AnyJSON.bool(isPremium)])
            .eq("id", value: userId.uuidString)
            .execute()
        
        print("✅ Updated premium status in profile: \(isPremium ? "PRO" : "Free")")
    }
    
    // MARK: - Clubs
    
    /// Create a new club
    /// - Parameters:
    ///   - name: The club name
    ///   - description: Optional club description
    ///   - isPrivate: Whether the club is private (invite-only)
    ///   - zipcode: Optional location zipcode for discoverability
    ///   - customJoinCode: Optional custom invite code (for private clubs). If nil, auto-generates one.
    func createClub(name: String, description: String, isPrivate: Bool = false, zipcode: String? = nil, customJoinCode: String? = nil) async throws -> Club {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        // Use custom join code if provided, otherwise generate one
        let joinCode: String
        if let customCode = customJoinCode, !customCode.isEmpty {
            joinCode = customCode.uppercased()
        } else {
            joinCode = generateJoinCode(from: name)
        }
        
        var clubData: [String: AnyJSON] = [
            "name": .string(name),
            "description": .string(description),
            "join_code": .string(joinCode),
            "created_by": .string(userId.uuidString),
            "is_private": .bool(isPrivate)
        ]
        
        // Add zipcode and geocode to coordinates if provided
        if let zipcode = zipcode, !zipcode.isEmpty {
            clubData["zipcode"] = .string(zipcode)
            
            // Try to geocode the zipcode to store coordinates
            do {
                let coordinate = try await geocodeZipcode(zipcode)
                clubData["latitude"] = .double(coordinate.latitude)
                clubData["longitude"] = .double(coordinate.longitude)
                print("📍 Geocoded \(zipcode) to: \(coordinate.latitude), \(coordinate.longitude)")
            } catch {
                print("⚠️ Could not geocode zipcode \(zipcode): \(error)")
                // Continue without coordinates - club will still be searchable by zipcode prefix
            }
        }
        
        let newClub: Club
        do {
            newClub = try await supabase
                .from("clubs")
                .insert(clubData)
                .select()
                .single()
                .execute()
                .value
        } catch {
            // Check for unique constraint violation (duplicate join code)
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("duplicate") || 
               errorMessage.contains("unique") || 
               errorMessage.contains("23505") ||
               errorMessage.contains("join_code") {
                print("❌ Duplicate invite code: \(joinCode)")
                throw CommunityError.duplicateInviteCode
            }
            // Re-throw other errors
            throw error
        }
        
        // Auto-join creator as founder
        try await joinClub(clubId: newClub.id, role: "founder")
        
        print("✅ Created club: \(newClub.name) with code: \(joinCode)")
        return newClub
    }
    
    /// Get a club by its join code (for waiver flow)
    func getClubByCode(_ code: String) async throws -> Club {
        let club: Club = try await supabase
            .from("clubs")
            .select()
            .eq("join_code", value: code.uppercased())
            .single()
            .execute()
            .value
        
        return club
    }
    
    /// Join a club using join code
    func joinClubWithCode(_ code: String) async throws {
        // Find club by join code
        let club = try await getClubByCode(code)
        
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
    
    // MARK: - Founder Management
    
    /// Delete a club (Founder only)
    /// This permanently deletes the club and all associated data
    func deleteClub(clubId: UUID) async throws {
        guard supabase.auth.currentUser != nil else {
            throw CommunityError.notAuthenticated
        }
        
        // Verify user is founder
        let role = try await getUserRole(clubId: clubId)
        guard role.canDeleteClub else {
            throw CommunityError.insufficientPermissions
        }
        
        // Delete in order: posts, event_rsvps, events, members, then club
        // Note: This could also be handled by CASCADE in database
        
        // Delete club posts
        try await supabase
            .from("club_posts")
            .delete()
            .eq("club_id", value: clubId.uuidString)
            .execute()
        
        // Delete club events and their RSVPs
        let events: [ClubEvent] = try await supabase
            .from("club_events")
            .select("id")
            .eq("club_id", value: clubId.uuidString)
            .execute()
            .value
        
        for event in events {
            try await supabase
                .from("event_rsvps")
                .delete()
                .eq("event_id", value: event.id.uuidString)
                .execute()
        }
        
        try await supabase
            .from("club_events")
            .delete()
            .eq("club_id", value: clubId.uuidString)
            .execute()
        
        // Delete leaderboard entries
        try await supabase
            .from("weekly_leaderboard")
            .delete()
            .eq("club_id", value: clubId.uuidString)
            .execute()
        
        // Delete all members
        try await supabase
            .from("club_members")
            .delete()
            .eq("club_id", value: clubId.uuidString)
            .execute()
        
        // Finally delete the club
        try await supabase
            .from("clubs")
            .delete()
            .eq("id", value: clubId.uuidString)
            .execute()
        
        // Reload clubs
        try await loadMyClubs()
        print("✅ Deleted club")
    }
    
    /// Transfer founder role to another member (Founder only)
    /// Current founder becomes a leader, target member becomes founder
    func transferFoundership(clubId: UUID, newFounderId: UUID) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        // Verify user is founder
        let role = try await getUserRole(clubId: clubId)
        guard role.canTransferOwnership else {
            throw CommunityError.insufficientPermissions
        }
        
        // Verify new founder is a member
        let members: [ClubMember] = try await supabase
            .from("club_members")
            .select()
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: newFounderId.uuidString)
            .execute()
            .value
        
        guard !members.isEmpty else {
            throw CommunityError.notAMember
        }
        
        // Update new founder to founder role
        try await supabase
            .from("club_members")
            .update(["role": AnyJSON.string("founder")])
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: newFounderId.uuidString)
            .execute()
        
        // Demote current founder to leader
        try await supabase
            .from("club_members")
            .update(["role": AnyJSON.string("leader")])
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        // Update club's created_by field
        try await supabase
            .from("clubs")
            .update(["created_by": AnyJSON.string(newFounderId.uuidString)])
            .eq("id", value: clubId.uuidString)
            .execute()
        
        // Reload members
        try await loadClubMembers(clubId: clubId)
        print("✅ Transferred foundership to \(newFounderId)")
    }
    
    /// Update club details (Founder only)
    func updateClub(
        clubId: UUID,
        name: String? = nil,
        description: String? = nil,
        isPrivate: Bool? = nil,
        zipcode: String? = nil
    ) async throws {
        guard supabase.auth.currentUser != nil else {
            throw CommunityError.notAuthenticated
        }
        
        // Verify user is founder
        let role = try await getUserRole(clubId: clubId)
        guard role.canEditClubDetails else {
            throw CommunityError.insufficientPermissions
        }
        
        var updateData: [String: AnyJSON] = [:]
        
        if let name = name {
            updateData["name"] = .string(name)
        }
        if let description = description {
            updateData["description"] = .string(description)
        }
        if let isPrivate = isPrivate {
            updateData["is_private"] = .bool(isPrivate)
        }
        if let zipcode = zipcode {
            updateData["zipcode"] = .string(zipcode)
        }
        
        guard !updateData.isEmpty else { return }
        
        try await supabase
            .from("clubs")
            .update(updateData)
            .eq("id", value: clubId.uuidString)
            .execute()
        
        // Reload clubs
        try await loadMyClubs()
        print("✅ Updated club details")
    }
    
    /// Regenerate the club's join code (Founder only)
    /// Returns the new join code
    @discardableResult
    func regenerateJoinCode(clubId: UUID) async throws -> String {
        guard supabase.auth.currentUser != nil else {
            throw CommunityError.notAuthenticated
        }
        
        // Verify user is founder
        let role = try await getUserRole(clubId: clubId)
        guard role.canRegenerateJoinCode else {
            throw CommunityError.insufficientPermissions
        }
        
        // Get club name for generating new code
        let club: Club = try await supabase
            .from("clubs")
            .select()
            .eq("id", value: clubId.uuidString)
            .single()
            .execute()
            .value
        
        // Generate new code
        let newCode = generateJoinCode(from: club.name)
        
        try await supabase
            .from("clubs")
            .update(["join_code": AnyJSON.string(newCode)])
            .eq("id", value: clubId.uuidString)
            .execute()
        
        // Reload clubs to get updated data
        try await loadMyClubs()
        print("✅ Regenerated join code: \(newCode)")
        return newCode
    }
    
    /// Get fresh club data by ID
    func getClub(clubId: UUID) async throws -> Club {
        let club: Club = try await supabase
            .from("clubs")
            .select()
            .eq("id", value: clubId.uuidString)
            .single()
            .execute()
            .value
        
        return club
    }
    
    /// Find public clubs near a zipcode
    @Published var nearbyClubs: [Club] = []
    
    /// Search radius in miles for nearby clubs
    private let searchRadiusMiles: Double = 50
    
    /// Geocode a ZIP code to coordinates using Apple's geocoder
    private func geocodeZipcode(_ zipcode: String) async throws -> CLLocationCoordinate2D {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(zipcode)
        
        guard let location = placemarks.first?.location else {
            throw CommunityError.geocodingFailed
        }
        
        return location.coordinate
    }
    
    func findNearbyClubs(zipcode: String) async throws {
        guard supabase.auth.currentUser != nil else {
            throw CommunityError.notAuthenticated
        }
        
        print("🔍 Geocoding zipcode: \(zipcode)")
        
        // Geocode the zipcode to get coordinates
        let coordinate: CLLocationCoordinate2D
        do {
            coordinate = try await geocodeZipcode(zipcode)
            print("📍 Coordinates: \(coordinate.latitude), \(coordinate.longitude)")
        } catch {
            print("⚠️ Geocoding failed, falling back to prefix search: \(error)")
            // Fallback to prefix-based search if geocoding fails
            try await findNearbyClubsByPrefix(zipcode: zipcode)
            return
        }
        
        // Call the database function to find nearby clubs
        print("🔍 Searching for clubs within \(searchRadiusMiles) miles...")
        
        async let nearbyResultsTask: [NearbyClub] = supabase
            .rpc("find_nearby_clubs", params: [
                "user_lat": coordinate.latitude,
                "user_lon": coordinate.longitude,
                "radius_miles": searchRadiusMiles
            ])
            .execute()
            .value
        
        // Also fetch global/universal clubs (no location set) - they appear in all searches
        async let globalClubsTask: [Club] = supabase
            .from("clubs")
            .select()
            .eq("is_private", value: false)
            .is("latitude", value: nil)
            .order("member_count", ascending: false)
            .limit(10)
            .execute()
            .value
        
        // Wait for both queries
        let (nearbyResults, globalClubs) = try await (nearbyResultsTask, globalClubsTask)
        
        // Combine nearby clubs with global clubs (nearby first, then global)
        var combinedClubs = nearbyResults.map { $0.asClub }
        combinedClubs.append(contentsOf: globalClubs)
        
        nearbyClubs = combinedClubs
        
        print("✅ Found \(nearbyResults.count) nearby clubs + \(globalClubs.count) global clubs")
        
        // Debug: Print club details with distance
        for result in nearbyResults {
            let distance = result.distanceMiles.map { String(format: "%.1f mi", $0) } ?? "?"
            print("   - \(result.name): \(distance) away, zipcode=\(result.zipcode ?? "nil")")
        }
        for club in globalClubs {
            print("   - \(club.name): 🌎 Global club")
        }
    }
    
    /// Fallback: Find clubs by ZIP code prefix (3 digits)
    private func findNearbyClubsByPrefix(zipcode: String) async throws {
        let zipcodePrefix = String(zipcode.prefix(3))
        print("🔍 Fallback: Searching for clubs with zipcode prefix: \(zipcodePrefix)")
        
        let clubs: [Club] = try await supabase
            .from("clubs")
            .select()
            .eq("is_private", value: false)
            .like("zipcode", pattern: "\(zipcodePrefix)%")
            .order("member_count", ascending: false)
            .limit(20)
            .execute()
            .value
        
        nearbyClubs = clubs
        print("✅ Found \(clubs.count) clubs with prefix \(zipcodePrefix)")
    }
    
    /// Find all public clubs (when no zipcode is provided)
    func findPublicClubs() async throws {
        guard supabase.auth.currentUser != nil else {
            throw CommunityError.notAuthenticated
        }
        
        print("🔍 Searching for all public clubs...")
        
        let clubs: [Club] = try await supabase
            .from("clubs")
            .select()
            .eq("is_private", value: false)
            .order("member_count", ascending: false)
            .limit(20)
            .execute()
            .value
        
        nearbyClubs = clubs
        print("✅ Found \(clubs.count) public clubs")
    }
    
    /// Join a club by its ID (for joining discovered clubs)
    func joinClubById(_ clubId: UUID) async throws {
        try await joinClub(clubId: clubId)
        print("✅ Joined club by ID: \(clubId)")
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
        elevationGain: Double = 0,
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
            "calories": .double(Double(calories)),
            "elevation_gain": .double(elevationGain)
        ]
        
        if let caption = caption {
            postData["content"] = .string(caption)
        }
        
        try await supabase
            .from("club_posts")
            .insert(postData)
            .execute()
        
        // Also update leaderboard
        try await updateLeaderboard(clubId: clubId, distance: distance, weight: weight, elevation: elevationGain)
        
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
                    elevationGain: item.elevationGain,
                    likeCount: item.likeCount,
                    commentCount: item.commentCount,
                    createdAt: item.createdAt,
                    author: item.authorId != nil ? PostAuthor(
                        id: item.authorId!,
                        username: item.authorUsername ?? "Unknown",
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
        let p_elevation: Double
    }
    
    private struct GetWeeklyLeaderboardParams: Encodable {
        let p_club_id: UUID
    }
    
    private struct GetClubFeedParams: Encodable {
        let p_club_id: UUID
        let p_limit: Int
    }
    
    // MARK: - Global Leaderboards (PRO Feature)
    
    @Published var globalLeaderboard: [GlobalLeaderboardEntry] = []
    
    /// Fetch global leaderboard for a specific metric type
    /// - Parameter type: The leaderboard metric type (distance, tonnage, elevation, consistency)
    /// - Returns: Array of leaderboard entries ranked by the metric
    func fetchGlobalLeaderboard(type: GlobalLeaderboardType) async throws -> [GlobalLeaderboardEntry] {
        guard supabase.auth.currentUser != nil else {
            throw CommunityError.notAuthenticated
        }
        
        let entries: [GlobalLeaderboardEntry] = try await supabase
            .from(type.tableName)
            .select()
            .order("rank", ascending: true)
            .limit(100)
            .execute()
            .value
        
        globalLeaderboard = entries
        print("✅ Loaded global leaderboard (\(type.displayName)): \(entries.count) entries")
        return entries
    }
    
    /// Update user's weekly leaderboard entry after a workout
    private func updateLeaderboard(clubId: UUID, distance: Double, weight: Double, elevation: Double = 0) async throws {
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        // Call the database function
        try await supabase
            .rpc(
                "update_leaderboard_entry",
                params: UpdateLeaderboardParams(
                    p_club_id: clubId,
                    p_user_id: userId,
                    p_distance: distance,
                    p_weight: weight,
                    p_elevation: elevation
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
    
    // MARK: - Events
    
    @Published var clubEvents: [ClubEvent] = []
    @Published var currentEventRSVPs: [EventRSVP] = []
    @Published var eventComments: [EventComment] = []
    
    /// Create a new club event (Leader/Founder only)
    func createEvent(
        clubId: UUID,
        title: String,
        eventDescription: String? = nil,
        startTime: Date,
        locationLat: Double? = nil,
        locationLong: Double? = nil,
        addressText: String? = nil,
        meetingPointDescription: String? = nil,
        requiredWeight: Int? = nil,
        waterRequirements: String? = nil
    ) async throws -> ClubEvent {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        // Verify user has permission (is leader or founder)
        let role = try await getUserRole(clubId: clubId)
        guard role.canCreateEvents else {
            throw CommunityError.insufficientPermissions
        }
        
        var eventData: [String: AnyJSON] = [
            "club_id": .string(clubId.uuidString),
            "created_by": .string(userId.uuidString),
            "title": .string(title),
            "start_time": .string(ISO8601DateFormatter().string(from: startTime))
        ]
        if let desc = eventDescription, !desc.isEmpty {
            eventData["description"] = .string(desc)
        }
        if let lat = locationLat {
            eventData["location_lat"] = .double(lat)
        }
        if let long = locationLong {
            eventData["location_long"] = .double(long)
        }
        if let address = addressText {
            eventData["address_text"] = .string(address)
        }
        if let meetingPoint = meetingPointDescription {
            eventData["meeting_point_description"] = .string(meetingPoint)
        }
        if let weight = requiredWeight {
            eventData["required_weight"] = .double(Double(weight))
        }
        if let water = waterRequirements {
            eventData["water_requirements"] = .string(water)
        }
        
        let newEvent: ClubEvent = try await supabase
            .from("club_events")
            .insert(eventData)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ Created event: \(newEvent.title)")
        
        // Reload events
        try await loadClubEvents(clubId: clubId)
        
        return newEvent
    }
    
    /// Update an existing event
    @discardableResult
    func updateEvent(eventId: UUID, updates: CreateEventInput) async throws -> ClubEvent {
        var updateData: [String: AnyJSON] = [
            "title": .string(updates.title),
            "start_time": .string(ISO8601DateFormatter().string(from: updates.startTime)),
            "address_text": .string(updates.addressText),
            "meeting_point_description": .string(updates.meetingPointDescription),
            "water_requirements": .string(updates.waterRequirements)
        ]
        updateData["description"] = .string(updates.eventDescription)
        
        if let lat = updates.locationLat {
            updateData["location_lat"] = .double(lat)
        }
        if let long = updates.locationLong {
            updateData["location_long"] = .double(long)
        }
        if let weight = updates.requiredWeight {
            updateData["required_weight"] = .double(Double(weight))
        }
        
        let updated: ClubEvent = try await supabase
            .from("club_events")
            .update(updateData)
            .eq("id", value: eventId.uuidString)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ Updated event: \(eventId)")
        try await loadClubEvents(clubId: updated.clubId)
        return updated
    }
    
    /// Delete an event
    func deleteEvent(eventId: UUID) async throws {
        try await supabase
            .from("club_events")
            .delete()
            .eq("id", value: eventId.uuidString)
            .execute()
        
        print("✅ Deleted event: \(eventId)")
    }
    
    /// Load upcoming events for a club
    func loadClubEvents(clubId: UUID) async throws {
        let events: [ClubEvent] = try await supabase
            .from("club_events")
            .select()
            .eq("club_id", value: clubId.uuidString)
            .gte("start_time", value: ISO8601DateFormatter().string(from: Date()))
            .order("start_time", ascending: true)
            .execute()
            .value
        
        clubEvents = events
        print("✅ Loaded \(events.count) upcoming events")
    }
    
    /// RSVP to an event
    func rsvpToEvent(eventId: UUID, status: RSVPStatus, declaredWeight: Int? = nil) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        // Check if user already has an RSVP
        let existingRSVPs: [EventRSVP] = try await supabase
            .from("event_rsvps")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        var rsvpData: [String: AnyJSON] = [
            "event_id": .string(eventId.uuidString),
            "user_id": .string(userId.uuidString),
            "status": .string(status.rawValue)
        ]
        
        if let weight = declaredWeight {
            rsvpData["declared_weight"] = .double(Double(weight))
        }
        
        if existingRSVPs.isEmpty {
            // Insert new RSVP
            try await supabase
                .from("event_rsvps")
                .insert(rsvpData)
                .execute()
        } else {
            // Update existing RSVP
            try await supabase
                .from("event_rsvps")
                .update(rsvpData)
                .eq("event_id", value: eventId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
        }
        
        print("✅ RSVP'd to event: \(status.rawValue)")
        
        // Reload RSVPs
        try await loadEventRSVPs(eventId: eventId)
    }
    
    /// Load RSVPs for an event
    func loadEventRSVPs(eventId: UUID) async throws {
        let rsvps: [EventRSVP] = try await supabase
            .from("event_rsvps")
            .select("""
                *,
                profiles!inner(username, avatar_url)
            """)
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value
        
        currentEventRSVPs = rsvps
        print("✅ Loaded \(rsvps.count) RSVPs")
    }
    
    /// Get user's RSVP status for an event
    func getUserRSVP(eventId: UUID) async throws -> EventRSVP? {
        guard let userId = supabase.auth.currentUser?.id else {
            return nil
        }
        
        let rsvps: [EventRSVP] = try await supabase
            .from("event_rsvps")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        return rsvps.first
    }
    
    /// Calculate RSVP summary for an event
    func getRSVPSummary(eventId: UUID) async throws -> RSVPSummary {
        try await loadEventRSVPs(eventId: eventId)
        
        let goingCount = currentEventRSVPs.filter { $0.status == .going }.count
        let maybeCount = currentEventRSVPs.filter { $0.status == .maybe }.count
        let outCount = currentEventRSVPs.filter { $0.status == .out }.count
        let totalWeight = currentEventRSVPs
            .filter { $0.status == .going }
            .compactMap { $0.declaredWeight }
            .reduce(0, +)
        
        return RSVPSummary(
            goingCount: goingCount,
            maybeCount: maybeCount,
            outCount: outCount,
            totalDeclaredWeight: totalWeight,
            rsvps: currentEventRSVPs
        )
    }
    
    // MARK: - Event Comments (The Wire)
    
    /// Post a comment to an event
    func postEventComment(eventId: UUID, clubId: UUID, content: String) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        let commentData: [String: AnyJSON] = [
            "event_id": .string(eventId.uuidString),
            "club_id": .string(clubId.uuidString),
            "user_id": .string(userId.uuidString),
            "content": .string(content),
            "post_type": .string("event_comment")
        ]
        
        try await supabase
            .from("club_posts")
            .insert(commentData)
            .execute()
        
        print("✅ Posted event comment")
        
        // Reload comments
        try await loadEventComments(eventId: eventId)
    }
    
    /// Load comments for an event
    func loadEventComments(eventId: UUID) async throws {
        // Query posts where event_id matches
        let comments: [EventComment] = try await supabase
            .from("club_posts")
            .select("""
                id, event_id, user_id, content, created_at,
                profiles!club_posts_user_id_fkey(username, avatar_url)
            """)
            .eq("event_id", value: eventId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
        
        eventComments = comments
        print("✅ Loaded \(comments.count) event comments")
    }
    
    // MARK: - Member Management & Roles
    
    @Published var clubMembers: [ClubMemberDetails] = []
    
    /// Get user's role in a club
    func getUserRole(clubId: UUID) async throws -> ClubRole {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        let members: [ClubMember] = try await supabase
            .from("club_members")
            .select()
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        guard let member = members.first else {
            throw CommunityError.notAMember
        }
        
        return ClubRole(rawValue: member.role) ?? .member
    }
    
    /// Load all members of a club with details
    func loadClubMembers(clubId: UUID) async throws {
        let members: [ClubMemberDetails] = try await supabase
            .from("club_members")
            .select("""
                *,
                profiles!inner(username, avatar_url)
            """)
            .eq("club_id", value: clubId.uuidString)
            .execute()
            .value
        
        clubMembers = members
        print("✅ Loaded \(members.count) club members")
    }
    
    /// Promote a member to leader (Founder only)
    func promoteToLeader(userId: UUID, clubId: UUID) async throws {
        let myRole = try await getUserRole(clubId: clubId)
        guard myRole.canManageMembers else {
            throw CommunityError.insufficientPermissions
        }
        
        try await supabase
            .from("club_members")
            .update(["role": AnyJSON.string("leader")])
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        print("✅ Promoted user to leader")
        
        // Reload members
        try await loadClubMembers(clubId: clubId)
    }
    
    /// Demote a leader to member (Founder only)
    func demoteToMember(userId: UUID, clubId: UUID) async throws {
        let myRole = try await getUserRole(clubId: clubId)
        guard myRole.canManageMembers else {
            throw CommunityError.insufficientPermissions
        }
        
        try await supabase
            .from("club_members")
            .update(["role": AnyJSON.string("member")])
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        print("✅ Demoted user to member")
        
        // Reload members
        try await loadClubMembers(clubId: clubId)
    }
    
    /// Remove a member from the club (Founder or Leader)
    func removeMember(userId: UUID, clubId: UUID) async throws {
        let myRole = try await getUserRole(clubId: clubId)
        guard myRole.canRemoveMembers else {
            throw CommunityError.insufficientPermissions
        }
        
        try await supabase
            .from("club_members")
            .delete()
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        print("✅ Removed member from club")
        
        // Reload members
        try await loadClubMembers(clubId: clubId)
    }
    
    // MARK: - Waiver System
    
    /// Sign waiver for a club
    func signWaiver(clubId: UUID, emergencyContactName: String, emergencyContactPhone: String) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw CommunityError.notAuthenticated
        }
        
        let emergencyContact = EmergencyContact(name: emergencyContactName, phone: emergencyContactPhone)
        let encoder = JSONEncoder()
        let emergencyContactData = try encoder.encode(emergencyContact)
        let emergencyContactJSON = String(data: emergencyContactData, encoding: .utf8) ?? "{}"
        
        try await supabase
            .from("club_members")
            .update([
                "waiver_signed_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date())),
                "emergency_contact_json": AnyJSON.string(emergencyContactJSON)
            ])
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        print("✅ Waiver signed for club")
    }
    
    /// Check if user has signed waiver for a club
    func hasSignedWaiver(clubId: UUID) async throws -> Bool {
        guard let userId = supabase.auth.currentUser?.id else {
            return false
        }
        
        let members: [ClubMemberDetails] = try await supabase
            .from("club_members")
            .select("waiver_signed_at")
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        return members.first?.hasSignedWaiver ?? false
    }
    
    /// Get emergency contact for a member (Founder only)
    func getMemberEmergencyContact(userId: UUID, clubId: UUID) async throws -> EmergencyContact? {
        let myRole = try await getUserRole(clubId: clubId)
        guard myRole.canViewEmergencyData else {
            throw CommunityError.insufficientPermissions
        }
        
        let members: [ClubMemberDetails] = try await supabase
            .from("club_members")
            .select("emergency_contact_json")
            .eq("club_id", value: clubId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        return members.first?.emergencyContact
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
    let zipcode: String?
    let latitude: Double?
    let longitude: Double?
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
        case zipcode
        case latitude
        case longitude
        case createdAt = "created_at"
    }
}

/// Club with distance information (returned from nearby search)
struct NearbyClub: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let joinCode: String
    let createdBy: UUID?
    let isPrivate: Bool
    let avatarUrl: String?
    let memberCount: Int
    let zipcode: String?
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date
    let distanceMiles: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case joinCode = "join_code"
        case createdBy = "created_by"
        case isPrivate = "is_private"
        case avatarUrl = "avatar_url"
        case memberCount = "member_count"
        case zipcode
        case latitude
        case longitude
        case createdAt = "created_at"
        case distanceMiles = "distance_miles"
    }
    
    /// Convert to regular Club for compatibility
    var asClub: Club {
        Club(
            id: id,
            name: name,
            description: description,
            joinCode: joinCode,
            createdBy: createdBy,
            isPrivate: isPrivate,
            avatarUrl: avatarUrl,
            memberCount: memberCount,
            zipcode: zipcode,
            latitude: latitude,
            longitude: longitude,
            createdAt: createdAt
        )
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
    let avatarUrl: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
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
    let elevationGain: Double?
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
        case elevationGain = "elevation_gain"
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
    let elevationGain: Double?
    let likeCount: Int
    let commentCount: Int
    let createdAt: Date
    let authorId: UUID?
    let authorUsername: String?
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
        case elevationGain = "elevation_gain"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case authorId = "author_id"
        case authorUsername = "author_username"
        case authorAvatarUrl = "author_avatar_url"
    }
}

struct LeaderboardEntry: Codable, Identifiable {
    let id = UUID() // Computed, not from DB
    let rank: Int
    let userId: UUID
    let username: String
    let avatarUrl: String?
    let totalDistance: Double
    let totalElevation: Double
    let totalWorkouts: Int
    
    enum CodingKeys: String, CodingKey {
        case rank
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case totalDistance = "total_distance"
        case totalElevation = "total_elevation"
        case totalWorkouts = "total_workouts"
    }
}

// MARK: - Global Leaderboard Types (PRO Feature)

/// The types of global leaderboard metrics available
enum GlobalLeaderboardType: String, CaseIterable, Identifiable {
    case distance = "distance"
    case tonnage = "tonnage"
    case elevation = "elevation"
    case consistency = "consistency"
    
    var id: String { rawValue }
    
    /// Display name shown in the UI
    var displayName: String {
        switch self {
        case .distance:
            return "Road Warriors"
        case .tonnage:
            return "Heavy Haulers"
        case .elevation:
            return "Vertical Gainers"
        case .consistency:
            return "Iron Discipline"
        }
    }
    
    /// Short label for picker
    var shortName: String {
        switch self {
        case .distance:
            return "Distance"
        case .tonnage:
            return "Tonnage"
        case .elevation:
            return "Elevation"
        case .consistency:
            return "Consistency"
        }
    }
    
    /// Unit label for displaying scores
    var unit: String {
        switch self {
        case .distance:
            return "mi"
        case .tonnage:
            return "lbs-mi"
        case .elevation:
            return "ft"
        case .consistency:
            return "days"
        }
    }
    
    /// Time period description
    var periodDescription: String {
        switch self {
        case .distance:
            return "This Week"
        case .tonnage:
            return "All Time"
        case .elevation:
            return "This Month"
        case .consistency:
            return "Last 30 Days"
        }
    }
    
    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .distance:
            return "figure.walk"
        case .tonnage:
            return "scalemass.fill"
        case .elevation:
            return "arrow.up.right"
        case .consistency:
            return "calendar.badge.checkmark"
        }
    }
    
    /// The Supabase view name to query
    var tableName: String {
        switch self {
        case .distance:
            return "global_leaderboard_distance_weekly"
        case .tonnage:
            return "global_leaderboard_tonnage_alltime"
        case .elevation:
            return "global_leaderboard_elevation_monthly"
        case .consistency:
            return "global_leaderboard_consistency"
        }
    }
}

/// Entry in a global leaderboard
struct GlobalLeaderboardEntry: Codable, Identifiable {
    var id: UUID { userId }
    let userId: UUID
    let username: String
    let avatarUrl: String?
    let isPremium: Bool
    let score: Double
    let rank: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case isPremium = "is_premium"
        case score
        case rank
    }
    
    /// Custom decoder to handle nil is_premium from database
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        username = try container.decode(String.self, forKey: .username)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        // Handle nil is_premium (defaults to false)
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        score = try container.decode(Double.self, forKey: .score)
        rank = try container.decode(Int.self, forKey: .rank)
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
    case notAMember
    case insufficientPermissions
    case waiverRequired
    case duplicateInviteCode
    case duplicateUsername
    case geocodingFailed
    
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
        case .notAMember:
            return "You are not a member of this club"
        case .insufficientPermissions:
            return "You don't have permission to perform this action"
        case .waiverRequired:
            return "You must sign a waiver to join this club"
        case .duplicateInviteCode:
            return "This invite code is already taken. Please choose a different one."
        case .duplicateUsername:
            return "This username is already taken. Please choose a different one."
        case .geocodingFailed:
            return "Could not find location for that ZIP code"
        }
    }
}

