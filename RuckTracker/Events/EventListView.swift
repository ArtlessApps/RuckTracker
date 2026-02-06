//
//  EventListView.swift
//  MARCH
//
//  Calendar/list of upcoming events for a club
//  Part of the "Tribe Command" v2.0 update
//

import SwiftUI

struct EventListView: View {
    let club: Club
    let userRole: ClubRole
    
    @StateObject private var communityService = CommunityService.shared
    @State private var showingCreateEvent = false
    @State private var selectedEvent: ClubEvent?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            AppColors.backgroundGradient
                .ignoresSafeArea()
            
            if isLoading {
                VStack {
                    ProgressView()
                        .tint(AppColors.primary)
                    Text("Loading events...")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, 8)
                }
            } else if communityService.clubEvents.isEmpty {
                emptyEventsView
            } else {
                eventsListView
            }
        }
        .task {
            await loadEvents()
        }
        .sheet(isPresented: $showingCreateEvent) {
            EventCreationView(club: club) { newEvent in
                // Event created, will be in the list after reload
                Task {
                    await loadEvents()
                }
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(
                event: event,
                club: club,
                canEditEvents: userRole.canCreateEvents,
                onEventDeleted: {
                    selectedEvent = nil
                    Task { await loadEvents() }
                },
                onEventUpdated: { updated in
                    Task {
                        await loadEvents()
                        selectedEvent = communityService.clubEvents.first { $0.id == updated.id } ?? updated
                    }
                }
            )
        }
    }
    
    // MARK: - Views
    
    private var emptyEventsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(AppColors.textSecondary)
            
            Text("No Upcoming Events")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Plan your next ruck with the crew.")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            if userRole.canCreateEvents {
                Button(action: { showingCreateEvent = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Event")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textOnLight)
                    .padding()
                    .background(AppColors.primary)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
    }
    
    private var eventsListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header with create button
                if userRole.canCreateEvents {
                    Button(action: { showingCreateEvent = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Event")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.primary, lineWidth: 1.5)
                        )
                    }
                }
                
                // Grouped by date
                ForEach(groupedEvents.keys.sorted(), id: \.self) { dateKey in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(dateKey.uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(1)
                        
                        ForEach(groupedEvents[dateKey] ?? []) { event in
                            Button(action: { selectedEvent = event }) {
                                EventCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var groupedEvents: [String: [ClubEvent]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        
        var groups: [String: [ClubEvent]] = [:]
        
        for event in communityService.clubEvents {
            let key = formatter.string(from: event.startTime)
            if groups[key] == nil {
                groups[key] = []
            }
            groups[key]?.append(event)
        }
        
        return groups
    }
    
    private func loadEvents() async {
        isLoading = true
        do {
            try await communityService.loadClubEvents(clubId: club.id)
        } catch {
            print("❌ Failed to load events: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Event Card

struct EventCard: View {
    let event: ClubEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let desc = event.eventDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Text(formattedTime)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                // Status indicator
                if event.isStartingSoon {
                    Text("SOON")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.textOnLight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.accentWarm)
                        .cornerRadius(6)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            // Location (if set)
            if let address = event.addressText, !address.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(AppColors.primary)
                    Text(address)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            // Bottom row: RSVP count
            HStack {
                Spacer()
                
                if let rsvpCount = event.rsvpCount, rsvpCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                        Text("\(rsvpCount)")
                    }
                    .font(.system(size: 13))
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
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: event.startTime)
    }
}
