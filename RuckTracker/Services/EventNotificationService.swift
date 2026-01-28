//
//  EventNotificationService.swift
//  MARCH
//
//  Handles scheduling and managing event reminder notifications
//  Part of the "Tribe Command" v2.0 update
//

import Foundation
import UserNotifications

/// Service for managing event reminder notifications
@MainActor
class EventNotificationService: ObservableObject {
    static let shared = EventNotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // Notification identifier prefix
    private let eventNotificationPrefix = "event_reminder_"
    
    private init() {}
    
    // MARK: - Authorization
    
    /// Request notification authorization
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            print(granted ? "✅ Notification authorization granted" : "❌ Notification authorization denied")
            return granted
        } catch {
            print("❌ Notification authorization error: \(error)")
            return false
        }
    }
    
    /// Check if notifications are authorized
    func isAuthorized() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    // MARK: - Event Reminders
    
    /// Schedule a reminder notification for an event
    /// - Parameters:
    ///   - event: The club event to schedule a reminder for
    ///   - reminderMinutesBefore: Minutes before the event to send reminder (default: 60)
    func scheduleEventReminder(for event: ClubEvent, reminderMinutesBefore: Int = 60) async {
        // Calculate reminder time
        let reminderDate = event.startTime.addingTimeInterval(-Double(reminderMinutesBefore * 60))
        
        // Don't schedule if reminder time is in the past
        guard reminderDate > Date() else {
            print("⏭️ Skipping reminder for past event: \(event.title)")
            return
        }
        
        // Check authorization
        guard await isAuthorized() else {
            print("❌ Cannot schedule reminder - notifications not authorized")
            return
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Ruck Starting Soon"
        content.body = "\(event.title) starts in \(reminderMinutesBefore) minutes. Get to the start point!"
        content.sound = .default
        content.categoryIdentifier = "EVENT_REMINDER"
        
        // Add event data for deep linking
        content.userInfo = [
            "eventId": event.id.uuidString,
            "clubId": event.clubId.uuidString,
            "type": "event_reminder"
        ]
        
        // Create trigger
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        // Create request with unique identifier
        let identifier = "\(eventNotificationPrefix)\(event.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            print("✅ Scheduled reminder for '\(event.title)' at \(reminderDate)")
        } catch {
            print("❌ Failed to schedule reminder: \(error)")
        }
    }
    
    /// Schedule reminders for multiple events
    func scheduleEventReminders(for events: [ClubEvent]) async {
        for event in events {
            await scheduleEventReminder(for: event)
        }
    }
    
    /// Cancel a scheduled reminder for an event
    func cancelEventReminder(for eventId: UUID) {
        let identifier = "\(eventNotificationPrefix)\(eventId.uuidString)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Cancelled reminder for event: \(eventId)")
    }
    
    /// Cancel all event reminders
    func cancelAllEventReminders() async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let eventReminders = pendingRequests
            .filter { $0.identifier.hasPrefix(eventNotificationPrefix) }
            .map { $0.identifier }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: eventReminders)
        print("🗑️ Cancelled \(eventReminders.count) event reminders")
    }
    
    /// Update reminder when event time changes
    func updateEventReminder(for event: ClubEvent) async {
        // Cancel existing reminder
        cancelEventReminder(for: event.id)
        
        // Schedule new reminder
        await scheduleEventReminder(for: event)
    }
    
    // MARK: - RSVP Integration
    
    /// Schedule reminder when user RSVPs "going" to an event
    func handleRSVP(event: ClubEvent, status: RSVPStatus) async {
        switch status {
        case .going:
            // Schedule reminder when user says they're going
            await scheduleEventReminder(for: event)
        case .maybe:
            // Keep reminder if exists (they might change to going)
            break
        case .out:
            // Cancel reminder when user says they're out
            cancelEventReminder(for: event.id)
        }
    }
    
    // MARK: - Notification Categories
    
    /// Register notification categories for action buttons
    func registerNotificationCategories() {
        // Event reminder category with actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_EVENT",
            title: "View Details",
            options: [.foreground]
        )
        
        let mapAction = UNNotificationAction(
            identifier: "OPEN_MAP",
            title: "Get Directions",
            options: [.foreground]
        )
        
        let eventCategory = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [viewAction, mapAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([eventCategory])
        print("✅ Registered notification categories")
    }
    
    // MARK: - Pending Notifications
    
    /// Get all pending event reminders
    func getPendingEventReminders() async -> [UNNotificationRequest] {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        return pendingRequests.filter { $0.identifier.hasPrefix(eventNotificationPrefix) }
    }
    
    /// Check if a reminder is scheduled for an event
    func hasReminderScheduled(for eventId: UUID) async -> Bool {
        let identifier = "\(eventNotificationPrefix)\(eventId.uuidString)"
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        return pendingRequests.contains { $0.identifier == identifier }
    }
}

// MARK: - Notification Delegate Extension

/// Extension to handle notification responses in AppDelegate or SceneDelegate
extension EventNotificationService {
    
    /// Handle notification action response
    func handleNotificationAction(identifier: String, eventId: UUID, clubId: UUID) {
        switch identifier {
        case "VIEW_EVENT":
            // Post notification to open event detail
            NotificationCenter.default.post(
                name: .openEventDetail,
                object: nil,
                userInfo: ["eventId": eventId, "clubId": clubId]
            )
            
        case "OPEN_MAP":
            // Post notification to open map directions
            NotificationCenter.default.post(
                name: .openEventMap,
                object: nil,
                userInfo: ["eventId": eventId, "clubId": clubId]
            )
            
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openEventDetail = Notification.Name("openEventDetail")
    static let openEventMap = Notification.Name("openEventMap")
}
