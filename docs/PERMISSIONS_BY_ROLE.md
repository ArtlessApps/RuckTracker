# MARCH v2.0 - Permissions by Role

This document outlines user permissions across club roles and subscription tiers.

---

## Club Roles Hierarchy

MARCH uses a three-tier role system for club management:

| Role | Description |
|------|-------------|
| **Founder** | Club creator with full administrative control |
| **Leader** | Trusted member who can manage events (delegated "Saturday Q" duty) |
| **Member** | Standard club participant |

### Club Role Permissions Matrix

| Permission | Founder | Leader | Member |
|------------|:-------:|:------:|:------:|
| **Club Management** |
| Delete club | ✅ | ❌ | ❌ |
| Edit club settings | ✅ | ❌ | ❌ |
| View/share join code | ✅ | ✅ | ❌ |
| **Member Management** |
| Promote member → leader | ✅ | ❌ | ❌ |
| Demote leader → member | ✅ | ❌ | ❌ |
| Remove members | ✅ | ❌ | ❌ |
| View emergency contacts | ✅ | ❌ | ❌ |
| View member list | ✅ | ✅ | ✅ |
| **Events (Command Center)** |
| Create events | ✅ | ✅ | ❌ |
| Edit/delete events | ✅ | ✅ | ❌ |
| View events | ✅ | ✅ | ✅ |
| RSVP to events | ✅ | ✅ | ✅ |
| Declare weight on RSVP | ✅ | ✅ | ✅ |
| Post event comments (The Wire) | ✅ | ✅ | ✅ |
| **Feed & Social** |
| View club feed | ✅ | ✅ | ✅ |
| Post workouts | ✅ | ✅ | ✅ |
| Like/comment on posts | ✅ | ✅ | ✅ |
| **Leaderboards** |
| View club leaderboard | ✅ | ✅ | ✅ |
| Appear on leaderboard | ✅ | ✅ | ✅ |
| **Waivers** |
| Configure waiver requirement | ✅ | ❌ | ❌ |
| Sign waiver | ✅ | ✅ | ✅ |

---

## Subscription Tiers

MARCH uses a "Trojan Horse" monetization model:
- **Free Tier ("Club OS")**: Everything needed to show up and participate
- **Pro Tier ("Digital Coach")**: Everything needed to get better

### Feature Access by Tier

| Feature | Free (Standard) | Pro ($4.99/mo) |
|---------|:---------------:|:--------------:|
| **Club Tools (Always Free)** |
| Join unlimited clubs | ✅ | ✅ |
| Sign waivers | ✅ | ✅ |
| RSVP to events | ✅ | ✅ |
| View event maps/details | ✅ | ✅ |
| Event chat (The Wire) | ✅ | ✅ |
| View club feed | ✅ | ✅ |
| Post workouts to clubs | ✅ | ✅ |
| **Training Plans** |
| View generated plans | ✅ | ✅ |
| Execute/start workouts | ❌ | ✅ |
| Dynamic Plan Generator | ❌ | ✅ |
| 10+ Static Programs | ❌ | ✅ |
| Weekly Challenges | ❌ | ✅ |
| **Tracking** |
| Basic GPS tracking (Open Ruck) | ✅ | ✅ |
| Time, distance, pace | ✅ | ✅ |
| Audio coaching cues | ❌ | ✅ |
| Heart rate zones | ❌ | ✅ |
| Interval timers | ❌ | ✅ |
| **Analytics** |
| Session summary | ✅ | ✅ |
| Basic map and stats | ✅ | ✅ |
| Tonnage trends | ❌ | ✅ |
| Vertical gain analysis | ❌ | ✅ |
| Progress charts over time | ❌ | ✅ |
| Achievement system | ❌ | ✅ |
| Export data | ❌ | ✅ |
| **Competition** |
| Club leaderboards | ✅ | ✅ |
| Global leaderboards | ❌ | ✅ |
| Pro badges | ❌ | ✅ |
| **Sharing** |
| Standard share card | ✅ | ✅ |
| Propaganda Mode | ❌ | ✅ |
| - Tonnage hero metric | ❌ | ✅ |
| - Club badge overlay | ❌ | ✅ |
| - Military-stencil theme | ❌ | ✅ |

---

## Ambassador Program

Ambassadors are Club Founders who help grow the MARCH community. They receive free Pro access as a reward.

### Qualification Requirements

| Requirement | Details |
|-------------|---------|
| Role | Must be **Founder** of at least one club |
| Members | Club must have **5 or more members** |
| Status | Automatically granted while requirements are met |

### Ambassador Benefits

- Full Pro subscription features at no cost
- Special "Ambassador" badge displayed in app
- Premium source shown as "Club Leader Perk"

### How It Works

1. User creates a club (becomes Founder)
2. User invites members to join via join code
3. When club reaches 5+ members, Ambassador status activates
4. Pro features unlock immediately
5. Status persists as long as club maintains 5+ members

### Marketing Message

> "Bring your club to MARCH for the RSVPs and Waivers. If you do, I'll give **you** the $60/year Training Plan subscription for free."

---

## Database Reference

Permissions are enforced via:

- **`club_members.role`**: `'founder'`, `'leader'`, `'member'`
- **`user_subscriptions.subscription_type`**: `'monthly'`, `'yearly'`, `'ambassador'`
- **`user_subscriptions.status`**: `'active'`, `'expired'`, `'cancelled'`

See `docs/DATABASE_SCHEMA.sql` for full schema details.

---

## Implementation Notes

### iOS App (PremiumManager.swift)

```swift
// Check feature access
func requiresPremium(for feature: PremiumFeature) -> Bool {
    return !isPremiumUser && feature.requiresPremium
}

// Ambassador check
func checkAmbassadorStatus() async {
    // Founder of club with 5+ members = free Pro
}
```

### Role Checks (CommunityService.swift)

```swift
// Permission helpers on ClubRole enum
var canCreateEvents: Bool { self == .founder || self == .leader }
var canManageMembers: Bool { self == .founder }
var canViewEmergencyData: Bool { self == .founder }
var canDeleteClub: Bool { self == .founder }
```
