//
//  EventDetailView.swift
//  MARCH
//
//  The "Lobby" for a ruck event - shows details, RSVPs, and "The Wire" comments
//  Part of the "Tribe Command" v2.0 update
//

import SwiftUI
import MapKit

struct EventDetailView: View {
    let event: ClubEvent
    let clubId: UUID
    
    @StateObject private var communityService = CommunityService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var userRSVP: EventRSVP?
    @State private var rsvpSummary: RSVPSummary?
    @State private var selectedStatus: RSVPStatus = .going
    @State private var declaredWeight: String = ""
    @State private var showingRSVPSheet = false
    @State private var newComment = ""
    @State private var isLoadingRSVPs = true
    @State private var isLoadingComments = true
    @State private var isSendingComment = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Event Header
                        eventHeaderSection
                        
                        // Countdown or Status
                        countdownSection
                        
                        // Map (if location set)
                        if event.hasLocation {
                            mapSection
                        }
                        
                        // Location Details
                        if event.addressText != nil || event.meetingPointDescription != nil {
                            locationDetailsSection
                        }
                        
                        // Gear Check
                        if event.requiredWeight != nil || event.waterRequirements != nil {
                            gearCheckSection
                        }
                        
                        // RSVP Section
                        rsvpSection
                        
                        // Attendees List
                        attendeesSection
                        
                        // The Wire (Comments)
                        wireSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .sheet(isPresented: $showingRSVPSheet) {
                RSVPSheet(
                    eventId: event.id,
                    initialStatus: selectedStatus,
                    initialWeight: declaredWeight,
                    onRSVP: { status, weight in
                        Task {
                            try? await communityService.rsvpToEvent(
                                eventId: event.id,
                                status: status,
                                declaredWeight: Int(weight)
                            )
                            
                            // Schedule/cancel notification based on RSVP status
                            await EventNotificationService.shared.handleRSVP(event: event, status: status)
                            
                            await loadData()
                        }
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Sections
    
    private var eventHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            HStack(spacing: 16) {
                Label(formattedDate, systemImage: "calendar")
                Label(formattedTime, systemImage: "clock")
            }
            .font(.system(size: 15))
            .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private var countdownSection: some View {
        Group {
            if event.isPast {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary)
                    Text("Event Completed")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.surface)
                )
            } else if event.isStartingSoon {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.accentWarm)
                    Text("Starting Soon!")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.accentWarm)
                    Spacer()
                    Text(countdownText)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.accentWarm.opacity(0.15))
                )
            } else {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(AppColors.primary)
                    Text("Starts in")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                    Text(countdownText)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.primary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.surface)
                )
            }
        }
    }
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOCATION")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)
            
            if let lat = event.locationLat, let long = event.locationLong {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: long),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )), annotationItems: [MapAnnotationItem(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: long))]) { item in
                    MapMarker(coordinate: item.coordinate, tint: .red)
                }
                .frame(height: 200)
                .cornerRadius(16)
                .onTapGesture {
                    openInMaps()
                }
                
                Button(action: openInMaps) {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        Text("Open in Maps")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
    
    private var locationDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let address = event.addressText, !address.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(AppColors.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Address")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                        Text(address)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            
            if let meetingPoint = event.meetingPointDescription, !meetingPoint.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "figure.wave")
                        .foregroundColor(AppColors.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Meeting Point")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                        Text(meetingPoint)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
        )
    }
    
    private var gearCheckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GEAR CHECK")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)
            
            HStack(spacing: 16) {
                if let weight = event.requiredWeight {
                    gearPill(icon: "scalemass.fill", text: "\(weight) lbs min")
                }
                
                if let water = event.waterRequirements, !water.isEmpty {
                    gearPill(icon: "drop.fill", text: water)
                }
            }
        }
    }
    
    private func gearPill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(AppColors.textPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
        )
    }
    
    private var rsvpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR RSVP")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)
            
            HStack(spacing: 12) {
                ForEach(RSVPStatus.allCases, id: \.self) { status in
                    Button(action: {
                        selectedStatus = status
                        showingRSVPSheet = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: status.icon)
                            Text(status.displayText)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(userRSVP?.status == status ? AppColors.textOnLight : AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(userRSVP?.status == status ? statusColor(status) : AppColors.surface)
                        )
                    }
                }
            }
            
            if let rsvp = userRSVP, let weight = rsvp.declaredWeight {
                Text("You're bringing \(weight) lbs")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
    
    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WHO'S IN")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(1)
                
                Spacer()
                
                if let summary = rsvpSummary {
                    Text("\(summary.goingCount) going")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.primary)
                }
            }
            
            if isLoadingRSVPs {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(AppColors.primary)
                    Spacer()
                }
                .padding()
            } else if let summary = rsvpSummary {
                // Group tonnage banner
                if summary.totalDeclaredWeight > 0 {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(AppColors.accentWarm)
                        Text("Group Tonnage: \(summary.groupTonnage)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.accentWarm.opacity(0.15))
                    )
                }
                
                // Attendee list
                VStack(spacing: 8) {
                    ForEach(summary.goingRSVPs) { rsvp in
                        attendeeRow(rsvp: rsvp)
                    }
                    
                    if !summary.maybeRSVPs.isEmpty {
                        Text("Maybe")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, 8)
                        
                        ForEach(summary.maybeRSVPs) { rsvp in
                            attendeeRow(rsvp: rsvp, isMaybe: true)
                        }
                    }
                }
            } else {
                Text("No RSVPs yet - be the first!")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .padding()
            }
        }
    }
    
    private func attendeeRow(rsvp: EventRSVP, isMaybe: Bool = false) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppColors.primary.opacity(isMaybe ? 0.3 : 0.5))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(rsvp.displayName?.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                )
            
            Text(rsvp.displayName ?? rsvp.username ?? "Unknown")
                .font(.system(size: 15))
                .foregroundColor(isMaybe ? AppColors.textSecondary : AppColors.textPrimary)
            
            Spacer()
            
            if let weight = rsvp.declaredWeight {
                Text("\(weight) lbs")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var wireSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THE WIRE")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)
            
            // Comment input
            HStack(spacing: 12) {
                TextField("Post an update...", text: $newComment)
                    .textFieldStyle(DarkTextFieldStyle())
                
                Button(action: sendComment) {
                    if isSendingComment {
                        ProgressView()
                            .tint(AppColors.textOnLight)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .foregroundColor(AppColors.textOnLight)
                .frame(width: 44, height: 44)
                .background(newComment.isEmpty ? AppColors.surface : AppColors.primary)
                .cornerRadius(12)
                .disabled(newComment.isEmpty || isSendingComment)
            }
            
            // Comments list
            if isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(AppColors.primary)
                    Spacer()
                }
                .padding()
            } else if communityService.eventComments.isEmpty {
                Text("No messages yet")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(communityService.eventComments) { comment in
                        commentRow(comment: comment)
                    }
                }
            }
        }
    }
    
    private func commentRow(comment: EventComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.displayName ?? comment.username ?? "Unknown")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Text(comment.createdAt.timeAgoDisplay())
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Text(comment.content)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.surface)
        )
    }
    
    // MARK: - Helpers
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: event.startTime)
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: event.startTime)
    }
    
    private var countdownText: String {
        let interval = event.timeUntilStart
        if interval < 0 {
            return "Started"
        }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours >= 24 {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
    
    private func statusColor(_ status: RSVPStatus) -> Color {
        switch status {
        case .going: return AppColors.successGreen
        case .maybe: return AppColors.pauseOrange
        case .out: return AppColors.textSecondary
        }
    }
    
    private func openInMaps() {
        guard let lat = event.locationLat, let long = event.locationLong else { return }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = event.title
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
    
    private func loadData() async {
        isLoadingRSVPs = true
        isLoadingComments = true
        
        do {
            userRSVP = try await communityService.getUserRSVP(eventId: event.id)
            rsvpSummary = try await communityService.getRSVPSummary(eventId: event.id)
            isLoadingRSVPs = false
            
            try await communityService.loadEventComments(eventId: event.id)
            isLoadingComments = false
        } catch {
            print("❌ Failed to load event data: \(error)")
            isLoadingRSVPs = false
            isLoadingComments = false
        }
    }
    
    private func sendComment() {
        guard !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSendingComment = true
        let commentText = newComment
        newComment = ""
        
        Task {
            do {
                try await communityService.postEventComment(eventId: event.id, clubId: clubId, content: commentText)
            } catch {
                print("❌ Failed to send comment: \(error)")
                newComment = commentText  // Restore on error
            }
            isSendingComment = false
        }
    }
}

// MARK: - RSVP Sheet

struct RSVPSheet: View {
    let eventId: UUID
    let initialStatus: RSVPStatus
    let initialWeight: String
    let onRSVP: (RSVPStatus, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatus: RSVPStatus
    @State private var weight: String
    
    init(eventId: UUID, initialStatus: RSVPStatus, initialWeight: String, onRSVP: @escaping (RSVPStatus, String) -> Void) {
        self.eventId = eventId
        self.initialStatus = initialStatus
        self.initialWeight = initialWeight
        self.onRSVP = onRSVP
        _selectedStatus = State(initialValue: initialStatus)
        _weight = State(initialValue: initialWeight)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Status selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("YOUR STATUS")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(1)
                        
                        ForEach(RSVPStatus.allCases, id: \.self) { status in
                            Button(action: { selectedStatus = status }) {
                                HStack {
                                    Image(systemName: status.icon)
                                        .foregroundColor(selectedStatus == status ? AppColors.textOnLight : AppColors.primary)
                                    Text(status.displayText)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(selectedStatus == status ? AppColors.textOnLight : AppColors.textPrimary)
                                    Spacer()
                                    if selectedStatus == status {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppColors.textOnLight)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedStatus == status ? AppColors.primary : AppColors.surface)
                                )
                            }
                        }
                    }
                    
                    // Weight declaration (only for "going")
                    if selectedStatus == .going {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DECLARE YOUR WEIGHT")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                                .tracking(1)
                            
                            Text("Flex on the group by declaring what you're bringing")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                            
                            HStack {
                                TextField("45", text: $weight)
                                    .textFieldStyle(DarkTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .frame(width: 100)
                                
                                Text("lbs")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Confirm button
                    Button(action: {
                        onRSVP(selectedStatus, weight)
                        dismiss()
                    }) {
                        Text("Confirm RSVP")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.textOnLight)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.primary)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("RSVP")
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
}
