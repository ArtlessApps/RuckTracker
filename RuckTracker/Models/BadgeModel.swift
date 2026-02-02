// Models/BadgeModel.swift
// Badge and Achievement System for RuckTracker
//
// Defines the badge catalog, tiers, and display properties.
// Badges are awarded for milestones (distance, tonnage, streaks) and PRO status.

import Foundation
import SwiftUI

// MARK: - Badge Tier

/// Tier levels for badges, determining visual styling and prestige
enum BadgeTier: String, Codable, CaseIterable {
    case bronze
    case silver
    case gold
    case platinum
    case pro
    
    /// Display name for the tier
    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .pro: return "PRO"
        }
    }
    
    /// Primary color for the tier
    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.80, green: 0.50, blue: 0.20)   // Bronze/copper
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.80)   // Silver
        case .gold: return Color(red: 1.00, green: 0.84, blue: 0.00)     // Gold
        case .platinum: return Color(red: 0.90, green: 0.90, blue: 0.98) // Platinum (silver-white)
        case .pro: return Color(red: 1.00, green: 0.84, blue: 0.00)      // Gold for PRO
        }
    }
    
    /// Secondary/accent color for gradients
    var accentColor: Color {
        switch self {
        case .bronze: return Color(red: 0.60, green: 0.35, blue: 0.15)
        case .silver: return Color(red: 0.55, green: 0.55, blue: 0.60)
        case .gold: return Color(red: 0.85, green: 0.65, blue: 0.00)
        case .platinum: return Color(red: 0.70, green: 0.70, blue: 0.85)
        case .pro: return Color.orange
        }
    }
    
    /// Gradient for badge background
    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, accentColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Badge Model

/// Represents a badge/achievement that can be earned
struct Badge: Identifiable, Codable, Hashable {
    let id: String                  // Unique identifier (e.g., "100_mile_club")
    let name: String                // Display name (e.g., "100 Mile Club")
    let description: String         // What it takes to earn this badge
    let iconSystemName: String      // SF Symbol name
    let tier: BadgeTier
    
    // Custom color override (uses tier color if nil)
    private let customColorHex: String?
    
    /// The display color for this badge
    var color: Color {
        if let hex = customColorHex {
            return Color(hex: hex)
        }
        return tier.color
    }
    
    /// Initialize with all properties
    init(
        id: String,
        name: String,
        description: String,
        iconSystemName: String,
        tier: BadgeTier,
        customColor: Color? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconSystemName = iconSystemName
        self.tier = tier
        self.customColorHex = customColor?.toHex()
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, iconSystemName, tier, customColorHex
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Badge, rhs: Badge) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Badge Catalog

/// Static catalog of all available badges in the app
final class BadgeCatalog {
    
    // MARK: - PRO Badge
    
    /// PRO Athlete badge - shown for premium subscribers
    static let proAthlete = Badge(
        id: "pro_athlete",
        name: "PRO Athlete",
        description: "Premium subscriber supporting MARCH development",
        iconSystemName: "crown.fill",
        tier: .pro,
        customColor: Color.yellow
    )
    
    // MARK: - Distance Badges
    
    /// 100 Mile Club - first major distance milestone
    static let hundredMileClub = Badge(
        id: "100_mile_club",
        name: "100 Mile Club",
        description: "Completed 100+ total miles of rucking",
        iconSystemName: "shoeprints.fill",
        tier: .bronze
    )
    
    /// 500 Mile Club - serious distance achievement
    static let fiveHundredMileClub = Badge(
        id: "500_mile_club",
        name: "500 Mile Club",
        description: "Completed 500+ total miles of rucking",
        iconSystemName: "shoeprints.fill",
        tier: .silver
    )
    
    /// 1000 Mile Club - elite distance achievement
    static let thousandMileClub = Badge(
        id: "1000_mile_club",
        name: "1000 Mile Club",
        description: "Completed 1,000+ total miles of rucking",
        iconSystemName: "shoeprints.fill",
        tier: .gold
    )
    
    // MARK: - Tonnage Badges
    
    /// Heavy Hauler - 10,000 lbs-mi tonnage
    static let heavyHauler = Badge(
        id: "heavy_hauler",
        name: "Heavy Hauler",
        description: "Achieved 10,000+ lbs-mi lifetime tonnage",
        iconSystemName: "dumbbell.fill",
        tier: .bronze,
        customColor: Color.orange
    )
    
    /// Freight Train - 50,000 lbs-mi tonnage
    static let freightTrain = Badge(
        id: "freight_train",
        name: "Freight Train",
        description: "Achieved 50,000+ lbs-mi lifetime tonnage",
        iconSystemName: "dumbbell.fill",
        tier: .silver,
        customColor: Color.orange
    )
    
    /// Iron Giant - 100,000 lbs-mi tonnage
    static let ironGiant = Badge(
        id: "iron_giant",
        name: "Iron Giant",
        description: "Achieved 100,000+ lbs-mi lifetime tonnage",
        iconSystemName: "dumbbell.fill",
        tier: .gold,
        customColor: Color.orange
    )
    
    // MARK: - Elevation Badges
    
    /// The Sherpa - 50,000 ft elevation gain
    static let theSherpa = Badge(
        id: "the_sherpa",
        name: "The Sherpa",
        description: "Gained 50,000+ feet of elevation",
        iconSystemName: "mountain.2.fill",
        tier: .silver,
        customColor: Color.purple
    )
    
    /// Everester - 29,032 ft in a single month (height of Everest)
    static let everester = Badge(
        id: "everester",
        name: "Everester",
        description: "Gained 29,032+ ft elevation in a single month",
        iconSystemName: "mountain.2.fill",
        tier: .gold,
        customColor: Color.purple
    )
    
    // MARK: - Program Completion Badges
    
    /// Selection Ready - completed GORUCK Selection Prep
    static let selectionReady = Badge(
        id: "selection_ready",
        name: "Selection Ready",
        description: "Completed the GORUCK Selection Prep program",
        iconSystemName: "flame.fill",
        tier: .platinum,
        customColor: Color.red
    )
    
    /// Heavy Ready - completed GORUCK Heavy/Tough Prep
    static let heavyReady = Badge(
        id: "heavy_ready",
        name: "Heavy Ready",
        description: "Completed the GORUCK Heavy/Tough Prep program",
        iconSystemName: "flame.fill",
        tier: .gold,
        customColor: Color.red
    )
    
    /// Light Ready - completed GORUCK Light Prep
    static let lightReady = Badge(
        id: "light_ready",
        name: "Light Ready",
        description: "Completed the GORUCK Light Prep program",
        iconSystemName: "flame.fill",
        tier: .silver,
        customColor: Color.red
    )
    
    // MARK: - Streak Badges
    
    /// Week Warrior - 7-day workout streak
    static let weekWarrior = Badge(
        id: "week_warrior",
        name: "Week Warrior",
        description: "Maintained a 7-day workout streak",
        iconSystemName: "calendar.badge.checkmark",
        tier: .bronze,
        customColor: Color.green
    )
    
    /// Month Master - 30-day workout streak
    static let monthMaster = Badge(
        id: "month_master",
        name: "Month Master",
        description: "Maintained a 30-day workout streak",
        iconSystemName: "calendar.badge.checkmark",
        tier: .silver,
        customColor: Color.green
    )
    
    /// Iron Discipline - 100+ workout days in a year
    static let ironDiscipline = Badge(
        id: "iron_discipline",
        name: "Iron Discipline",
        description: "Completed 100+ workout days in a single year",
        iconSystemName: "calendar.badge.checkmark",
        tier: .gold,
        customColor: Color.green
    )
    
    // MARK: - Community Badges
    
    /// Club Founder - founded a club with 5+ members
    static let clubFounder = Badge(
        id: "club_founder",
        name: "Club Founder",
        description: "Founded a club with 5+ active members",
        iconSystemName: "person.3.fill",
        tier: .silver,
        customColor: Color.blue
    )
    
    /// Community Leader - founded a club with 25+ members
    static let communityLeader = Badge(
        id: "community_leader",
        name: "Community Leader",
        description: "Founded a club with 25+ active members",
        iconSystemName: "person.3.fill",
        tier: .gold,
        customColor: Color.blue
    )
    
    // MARK: - All Badges
    
    /// All available badges in display order
    static let allBadges: [Badge] = [
        // PRO first (most prestigious status badge)
        proAthlete,
        
        // Program completion (achievement unlocks)
        selectionReady,
        heavyReady,
        lightReady,
        
        // Distance milestones
        thousandMileClub,
        fiveHundredMileClub,
        hundredMileClub,
        
        // Tonnage milestones
        ironGiant,
        freightTrain,
        heavyHauler,
        
        // Elevation milestones
        everester,
        theSherpa,
        
        // Streaks
        ironDiscipline,
        monthMaster,
        weekWarrior,
        
        // Community
        communityLeader,
        clubFounder
    ]
    
    /// Get a badge by its ID
    static func badge(for id: String) -> Badge? {
        allBadges.first { $0.id == id }
    }
    
    /// Featured badges to highlight in the trophy case
    static let featuredBadges: [Badge] = [
        proAthlete,
        selectionReady,
        thousandMileClub,
        ironGiant,
        everester,
        ironDiscipline
    ]
}

// MARK: - User Badge Model (for database sync)

/// Represents a badge earned by a user, stored in the database
struct UserBadge: Codable, Identifiable {
    var id: String { "\(userId.uuidString)_\(badgeId)" }
    let userId: UUID
    let badgeId: String
    let awardedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case badgeId = "badge_id"
        case awardedAt = "awarded_at"
    }
    
    /// Get the badge definition for this user badge
    var badge: Badge? {
        BadgeCatalog.badge(for: badgeId)
    }
}

// MARK: - Color Extensions

extension Color {
    /// Convert Color to hex string
    /// Note: init(hex:) is defined in AppColors.swift
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        
        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
