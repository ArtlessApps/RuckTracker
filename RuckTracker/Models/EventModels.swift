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
    
    var canManageMembers: Bool {
        self == .founder
    }
    
    var canViewEmergencyData: Bool {
        self == .founder
    }
    
    var canDeleteClub: Bool {
        self == .founder
    }
}

// MARK: - Club Event

struct ClubEvent: Codable, Identifiable {
    let id: UUID
    let clubId: UUID
    let createdBy: UUID
    var title: String
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
    
    // Joined data (from RPC)
    var username: String?
    var displayName: String?
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
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

// MARK: - Event Comment (Wire)

struct EventComment: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    var content: String
    let createdAt: Date
    
    // Joined data
    var username: String?
    var displayName: String?
    var avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
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

struct ClubMemberDetails: Codable, Identifiable {
    let id: UUID  // Same as userId for Identifiable
    let clubId: UUID
    let userId: UUID
    let role: ClubRole
    let joinedAt: Date
    let waiverSignedAt: Date?
    let emergencyContact: EmergencyContact?
    
    // Joined profile data
    var username: String?
    var displayName: String?
    var avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case waiverSignedAt = "waiver_signed_at"
        case emergencyContact = "emergency_contact_json"
        case username
        case displayName = "display_name"
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
        self.emergencyContact = try container.decodeIfPresent(EmergencyContact.self, forKey: .emergencyContact)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
    }
    
    var hasSignedWaiver: Bool {
        waiverSignedAt != nil
    }
}

// MARK: - Event Creation Input

struct CreateEventInput {
    var title: String = ""
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
