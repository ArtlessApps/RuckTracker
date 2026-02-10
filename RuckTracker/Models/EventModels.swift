//
//  EventModels.swift
//  MARCH
//
//  Models for club events, RSVPs, and waiver system
//  Part of the "Tribe Command" v2.0 update
//

import Foundation

// MARK: - RSVP Status

enum RSVPStatus: String, Codable, CaseIterable {
    case going = "going"
    case maybe = "maybe"
    case out = "out"
    
    var displayText: String {
        switch self {
        case .going: return "I'm In"
        case .maybe: return "Maybe"
        case .out: return "Out"
        }
    }
    
    var icon: String {
        switch self {
        case .going: return "checkmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        case .out: return "xmark.circle.fill"
        }
    }
}

// MARK: - Club Member Role

enum ClubRole: String, Codable, CaseIterable {
    case founder = "founder"
    case leader = "leader"
    case member = "member"
    
    var displayText: String {
        switch self {
        case .founder: return "Founder"
        case .leader: return "Leader"
        case .member: return "Member"
        }
    }
    
    var canCreateEvents: Bool {
        self == .founder || self == .leader
    }
    
    /// Promote/demote members (founder only)
    var canManageMembers: Bool {
        self == .founder
    }
    
    /// View emergency contacts (founders and leaders as moderators)
    var canViewEmergencyData: Bool {
        self == .founder || self == .leader
    }
    
    /// Remove members from the club (founders and leaders as moderators)
    var canRemoveMembers: Bool {
        self == .founder || self == .leader
    }
    
    var canDeleteClub: Bool {
        self == .founder
    }
    
    var canTransferOwnership: Bool {
        self == .founder
    }
    
    var canEditClubDetails: Bool {
        self == .founder
    }
    
    var canRegenerateJoinCode: Bool {
        self == .founder
    }
    
    var canInviteMembers: Bool {
        self == .founder || self == .leader
    }
}

// MARK: - Club Event

struct ClubEvent: Codable, Identifiable {
    let id: UUID
    let clubId: UUID
    let createdBy: UUID
    var title: String
    var eventDescription: String?
    var startTime: Date
    var locationLat: Double?
    var locationLong: Double?
    var addressText: String?
    var meetingPointDescription: String?
    var requiredWeight: Int?
    var waterRequirements: String?
    let createdAt: Date
    
    // Joined data (from RPC)
    var creatorUsername: String?
    var creatorDisplayName: String?
    var rsvpCount: Int?
    var totalDeclaredWeight: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case clubId = "club_id"
        case createdBy = "created_by"
        case title
        case eventDescription = "description"
        case startTime = "start_time"
        case locationLat = "location_lat"
        case locationLong = "location_long"
        case addressText = "address_text"
        case meetingPointDescription = "meeting_point_description"
        case requiredWeight = "required_weight"
        case waterRequirements = "water_requirements"
        case createdAt = "created_at"
        case creatorUsername = "creator_username"
        case creatorDisplayName = "creator_display_name"
        case rsvpCount = "rsvp_count"
        case totalDeclaredWeight = "total_declared_weight"
    }
    
    /// Check if event is in the past
    var isPast: Bool {
        startTime < Date()
    }
    
    /// Check if event is starting soon (within 2 hours)
    var isStartingSoon: Bool {
        let twoHoursFromNow = Date().addingTimeInterval(2 * 60 * 60)
        return startTime > Date() && startTime <= twoHoursFromNow
    }
    
    /// Time until event starts
    var timeUntilStart: TimeInterval {
        startTime.timeIntervalSinceNow
    }
    
    /// Has a location set
    var hasLocation: Bool {
        locationLat != nil && locationLong != nil
    }
}

// MARK: - Event RSVP

struct EventRSVP: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    var status: RSVPStatus
    var declaredWeight: Int?
    let createdAt: Date
    var updatedAt: Date?
    
    // Joined data (from profiles)
    var username: String?
    var avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case status
        case declaredWeight = "declared_weight"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case username
        case avatarUrl = "avatar_url"
        case profiles
    }
    
    enum ProfileKeys: String, CodingKey {
        case username
        case avatarUrl = "avatar_url"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        eventId = try container.decode(UUID.self, forKey: .eventId)
        userId = try container.decode(UUID.self, forKey: .userId)
        status = try container.decode(RSVPStatus.self, forKey: .status)
        declaredWeight = try container.decodeIfPresent(Int.self, forKey: .declaredWeight)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        
        // Decode nested profiles object from Supabase join
        if let profilesContainer = try? container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profiles) {
            username = try? profilesContainer.decode(String.self, forKey: .username)
            avatarUrl = try? profilesContainer.decode(String.self, forKey: .avatarUrl)
        } else {
            // Fallback: try flat keys (e.g. from RPC calls)
            username = try? container.decode(String.self, forKey: .username)
            avatarUrl = try? container.decode(String.self, forKey: .avatarUrl)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(eventId, forKey: .eventId)
        try container.encode(userId, forKey: .userId)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(declaredWeight, forKey: .declaredWeight)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Event Comment (Wire)

struct EventComment: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    var content: String
    let createdAt: Date
    
    // Joined data from profiles
    var username: String?
    var avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case profiles
    }
    
    enum ProfileKeys: String, CodingKey {
        case username
        case avatarUrl = "avatar_url"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        eventId = try container.decode(UUID.self, forKey: .eventId)
        userId = try container.decode(UUID.self, forKey: .userId)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // Decode nested profiles object
        if let profilesContainer = try? container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profiles) {
            username = try? profilesContainer.decode(String.self, forKey: .username)
            avatarUrl = try? profilesContainer.decode(String.self, forKey: .avatarUrl)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(eventId, forKey: .eventId)
        try container.encode(userId, forKey: .userId)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Emergency Contact

struct EmergencyContact: Codable {
    var name: String
    var phone: String
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Waiver Info

struct WaiverInfo: Codable {
    let signedAt: Date
    let emergencyContact: EmergencyContact
    
    enum CodingKeys: String, CodingKey {
        case signedAt = "signed_at"
        case emergencyContact = "emergency_contact"
    }
}

// MARK: - Extended Club Member (with waiver info)

struct ClubMemberDetails: Decodable, Identifiable {
    let id: UUID  // Same as userId for Identifiable
    let clubId: UUID
    let userId: UUID
    let role: ClubRole
    let joinedAt: Date
    let waiverSignedAt: Date?
    let emergencyContact: EmergencyContact?
    
    // Joined profile data
    var username: String?
    var avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case waiverSignedAt = "waiver_signed_at"
        case emergencyContact = "emergency_contact_json"
        case profiles
    }
    
    enum ProfileKeys: String, CodingKey {
        case username
        case avatarUrl = "avatar_url"
    }
    
    // Computed id for Identifiable (use userId)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.clubId = try container.decode(UUID.self, forKey: .clubId)
        self.userId = try container.decode(UUID.self, forKey: .userId)
        self.id = self.userId
        self.role = try container.decode(ClubRole.self, forKey: .role)
        self.joinedAt = try container.decode(Date.self, forKey: .joinedAt)
        self.waiverSignedAt = try container.decodeIfPresent(Date.self, forKey: .waiverSignedAt)
        // emergency_contact_json: DB may return jsonb as object or (if stored as string) as JSON string
        self.emergencyContact = Self.decodeEmergencyContact(from: container)
        // Username and avatar come from joined profiles object (Supabase returns nested "profiles": { "username", "avatar_url" })
        self.username = nil
        self.avatarUrl = nil
        if let profilesContainer = try? container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profiles) {
            self.username = try? profilesContainer.decode(String.self, forKey: .username)
            self.avatarUrl = try? profilesContainer.decode(String.self, forKey: .avatarUrl)
        }
    }
    
    /// Decode emergency_contact_json whether Supabase returns it as a jsonb object or as a JSON string.
    private static func decodeEmergencyContact(from container: KeyedDecodingContainer<CodingKeys>) -> EmergencyContact? {
        guard container.contains(.emergencyContact) else { return nil }
        do {
            return try container.decode(EmergencyContact.self, forKey: .emergencyContact)
        } catch {
            if let jsonString = try? container.decode(String.self, forKey: .emergencyContact),
               let data = jsonString.data(using: .utf8) {
                return try? JSONDecoder().decode(EmergencyContact.self, from: data)
            }
            return nil
        }
    }
    
    var hasSignedWaiver: Bool {
        waiverSignedAt != nil
    }
}

// MARK: - Event Creation Input

struct CreateEventInput {
    var title: String = ""
    var eventDescription: String = ""
    var startTime: Date = Date().addingTimeInterval(24 * 60 * 60) // Tomorrow by default
    var locationLat: Double?
    var locationLong: Double?
    var addressText: String = ""
    var meetingPointDescription: String = ""
    var requiredWeight: Int?
    var waterRequirements: String = ""
    
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        startTime > Date()
    }
}

// MARK: - RSVP Summary

struct RSVPSummary {
    let goingCount: Int
    let maybeCount: Int
    let outCount: Int
    let totalDeclaredWeight: Int
    let rsvps: [EventRSVP]
    
    var goingRSVPs: [EventRSVP] {
        rsvps.filter { $0.status == .going }
    }
    
    var maybeRSVPs: [EventRSVP] {
        rsvps.filter { $0.status == .maybe }
    }
    
    /// Calculate "Group Tonnage" - total weight the group will carry
    var groupTonnage: String {
        if totalDeclaredWeight >= 2000 {
            return String(format: "%.1f", Double(totalDeclaredWeight) / 2000.0) + " tons"
        } else {
            return "\(totalDeclaredWeight) lbs"
        }
    }
}
