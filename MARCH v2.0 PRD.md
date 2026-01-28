This PRD synthesizes our "Runna + Heylo" strategy into a concrete roadmap. It is designed to be handed to a product manager or developer (or Cursor) to execute the **"Tribe Command" Update**.

---

# Product Requirements Document (PRD) – MARCH v2.0

**Internal Codename:** "Tribe Command"
**Primary Objective:** Solve the "Admin Tax" for volunteer Ruck Club leaders to drive group adoption.
**Secondary Objective:** Leverage "Tonnage" and "Club Badges" to drive viral organic growth.

---

## 1. Executive Summary

RuckTracker v1.0 successfully built the engine for *competition* (Leaderboards).
RuckTracker v2.0 will build the engine for **coordination**. We are pivoting from "just a tracker" to a "Club Operating System." We will provide the essential utilities—Event Scheduling, Roll Call, Waivers, and Route Sharing—that make a Club Leader's life easier, effectively replacing their messy mix of Facebook Groups, spreadsheets, and texts.

## 2. Target Personas

* **Primary:** **The "Volunteer Founder"** (e.g., F3 Qs, GORUCK Club Leaders).
* *Pain Points:* Liability fears (waivers), messy communication (WhatsApp/FB), "ghost" attendees, route planning fatigue.
* *Goal:* Reduce admin time, increase member retention.


* **Secondary:** **The "Tribe Member"**
* *Pain Points:* "Where are we meeting?", "What weight should I bring?", "Did I miss the update?"
* *Goal:* Social signaling (showing off tonnage), knowing exactly where/when to show up.



---

## 3. Core Feature Specifications

### A. The "Command Center" (Events Engine)

*Replacing the Facebook Event/WhatsApp Thread.*

**Feature:** **Club Calendar & Event Details**

* **Description:** A dedicated tab in the "Tribe" view showing upcoming rucks.
* **Data Requirements:**
* Title (e.g., "Saturday Sufferfest")
* DateTime (Start time is critical)
* **Location Pin:** Lat/Long for map integration (clickable to open Apple/Google Maps).
* **Meeting Point Description:** Text field (e.g., "Park behind the Wendy's").
* **Gear Check:** Required Weight (e.g., "30lb min") and Water requirements.


* **User Story:** "As a Leader, I want to post the Saturday Ruck details once so I don't have to answer 15 texts asking for the address."

**Feature:** **Smart RSVPs & Roll Call**

* **Description:** Members tap "I'm In," "Maybe," or "Out."
* **The "Flex" Twist:** When RSVPing, users declare their intended weight (e.g., "I'm bringing 45lbs").
* **Admin View:** Leader sees a list of "Who's In" + "Total Expected Group Tonnage" (Vanity Metric).
* **Notifications:** Automated push notification 1 hour before start: "Ruck starts in 1 hour. Get to the start point."

**Feature:** **Event Comms (The "Wire")**

* **Description:** A simple, linear comment thread attached specifically to the *Event*, not the general club feed.
* **Use Case:** "Running 5 mins late!", "Is parking free?", "Post-ruck coffee is at Starbucks."

### B. The "Digital Armory" (Club Admin Tools)

*Solving the Liability and Hierarchy problems.*

**Feature:** **Multi-Tier Roles**

* **Founder:** Can delete club, promote/demote leaders, view emergency data.
* **Leader:** Can create/edit events, manage RSVPs.
* **Member:** Can view, RSVP, and post workout results.
* **Why:** Founders need to delegate the "Saturday Q" duty without giving away the keys to the castle.

**Feature:** **The "Ironclad" Waiver System (The Trojan Horse)**

* **Description:** To join a Club (or RSVP to a Club Event), a user *must* have a digitally signed liability waiver on file for that specific club.
* **Implementation:**
* Screen 1: "Safety Briefing" (Text scroll).
* Screen 2: "Emergency Contact" (Name/Phone input required).
* Screen 3: "Digital Signature" (Tap to sign).


* **Value Prop:** This is the #1 feature that will convince a Leader to migrate their user base to your app.

### C. The "Propaganda Machine" (Viral Sharing)

*The "Runna" playbook adapted for the Rucking aesthetic.*

**Feature:** **"Tonnage" Share Card**

* **Logic:** Calculate `Tonnage = Ruck Weight (lbs) × Distance (miles)`. (e.g., 30lbs * 4 miles = 120 Mile-Pounds, or convert to total lbs moved).
* **Visual:** Gritty, military-stencil aesthetic.
* **Dynamic Data:**
* **Hero Metric:** MASSIVE font for Weight Carried (e.g., "45 LBS").
* **Sub-Metric:** Tonnage/Volume.
* **Map Trace:** The route line.



**Feature:** **The "Tribe Badge" Context**

* **Description:** When a workout is generated from within a Club context (or shared), the image MUST stamp the Club Name at the bottom.
* **Format:** "TRAINING WITH [NORTH COUNTY RUCK CLUB]"
* **Growth Loop:** Every Instagram Story becomes an ad for the local club, incentivizing the Leader to encourage posting.

---

## 4. Technical Migration Plan (Data Layer)

### Schema Updates (Supabase/PostgreSQL)

1. **Modify `club_members`:**
* Upgrade `role` column to enum: `['founder', 'leader', 'member']`.
* Add `waiver_signed_at` (Timestamp) and `emergency_contact_json` (JSONB).


2. **Create `club_events`:**
* FK to `club_id` and `created_by` (Profile ID).
* Fields: `title`, `start_time`, `location_lat`, `location_long`, `address_text`, `required_weight`.


3. **Create `event_rsvps`:**
* FK to `event_id` and `user_id`.
* Fields: `status` ('going', 'maybe', 'out'), `declared_weight`.


4. **Update `club_posts`:**
* Add nullable `event_id` FK to allow comments to be attached to events.



---

## 5. UI/UX Roadmap (Views to Build)

1. **`EventCreationView`:** (Admin Only) Form to pick date, map pin, and add details.
2. **`EventDetailView`:** The "Lobby" for the ruck. Shows map, time, RSVP list, and comment thread.
3. **`WaiverOnboardingSheet`:** A modal that blocks entry to the Club until safety info is provided.
4. **`ShareCardEditor`:** Updated canvas to render the "Tonnage" and "Club Name" dynamically.

## 6. Success Metrics (KPIs)

* **North Star:** **Events Created per Active Club.** (Are leaders actually using the coordination tools?)
* **Growth:** **Share Card Exports containing Club Names.** (Is the viral loop working?)
* **Retention:** **RSVP-to-Show Rate.** (Are people committing and showing up?)