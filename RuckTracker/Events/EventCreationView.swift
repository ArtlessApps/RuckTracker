//
//  EventCreationView.swift
//  MARCH
//
//  Event creation form for Leaders and Founders
//  Part of the "Tribe Command" v2.0 update
//

import SwiftUI
import MapKit
import CoreLocation

struct EventCreationView: View {
    let club: Club
    let existingEvent: ClubEvent?
    let onEventCreated: ((ClubEvent) -> Void)?
    let onEventUpdated: ((ClubEvent) -> Void)?
    
    @StateObject private var communityService = CommunityService.shared
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var title = ""
    @State private var eventDescription = ""
    @State private var startDate = Date().addingTimeInterval(24 * 60 * 60)
    @State private var addressText = ""
    @State private var meetingPointDescription = ""
    
    // Map state (default region; may be updated to user location when opening picker)
    @State private var showingMapPicker = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // UI state
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    private var isEditMode: Bool { existingEvent != nil }
    
    init(club: Club, existingEvent: ClubEvent? = nil, onEventCreated: ((ClubEvent) -> Void)? = nil, onEventUpdated: ((ClubEvent) -> Void)? = nil) {
        self.club = club
        self.existingEvent = existingEvent
        self.onEventCreated = onEventCreated
        self.onEventUpdated = onEventUpdated
    }
    
    private var isFormValid: Bool {
        let titleValid = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isEditMode {
            return titleValid
        }
        return titleValid && startDate > Date()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Event Title
                        formSection(title: "Event Details") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Title")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                TextField("Saturday Sufferfest", text: $title)
                                    .textFieldStyle(DarkTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Description")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                TextField("What to expect, route notes, etc.", text: $eventDescription, axis: .vertical)
                                    .textFieldStyle(DarkTextFieldStyle())
                                    .lineLimit(3...6)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Date & Time")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                DatePicker(
                                    "Start Time",
                                    selection: $startDate,
                                    in: (isEditMode ? startDate : Date())...,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                .tint(AppColors.primary)
                                .colorScheme(.dark)
                            }
                        }
                        
                        // Location
                        formSection(title: "Location") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Address")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                TextField("123 Main St, City, State", text: $addressText)
                                    .textFieldStyle(DarkTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Meeting Point")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                TextField("Park behind the Wendy's", text: $meetingPointDescription)
                                    .textFieldStyle(DarkTextFieldStyle())
                            }
                            
                            // Map Pin Button
                            Button(action: { showingMapPicker = true }) {
                                HStack {
                                    Image(systemName: selectedLocation != nil ? "mappin.circle.fill" : "mappin.circle")
                                        .font(.system(size: 20))
                                    
                                    Text(selectedLocation != nil ? "Location Set" : "Set Pin on Map")
                                        .font(.system(size: 15, weight: .medium))
                                    
                                    Spacer()
                                    
                                    if selectedLocation != nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.successGreen)
                                    } else {
                                        Image(systemName: "chevron.right")
                                    }
                                }
                                .foregroundColor(AppColors.primary)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.surface)
                                )
                            }
                        }
                        
                        // Error Message
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.accentWarm)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.accentWarm.opacity(0.1))
                                )
                        }
                        
                        // Create / Save Button
                        Button(action: isEditMode ? saveEventChanges : createEvent) {
                            if isCreating {
                                ProgressView()
                                    .tint(AppColors.textOnLight)
                            } else {
                                Text(isEditMode ? "Save Changes" : "Create Event")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(AppColors.textOnLight)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? AppColors.primary : AppColors.primary.opacity(0.5))
                        .cornerRadius(12)
                        .disabled(!isFormValid || isCreating)
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditMode ? "Edit Event" : "Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .sheet(isPresented: $showingMapPicker) {
                MapLocationPicker(
                    region: $mapRegion,
                    selectedLocation: $selectedLocation
                )
            }
            .onAppear {
                if let event = existingEvent {
                    title = event.title
                    eventDescription = event.eventDescription ?? ""
                    startDate = event.startTime
                    addressText = event.addressText ?? ""
                    meetingPointDescription = event.meetingPointDescription ?? ""
                    if let lat = event.locationLat, let long = event.locationLong {
                        selectedLocation = CLLocationCoordinate2D(latitude: lat, longitude: long)
                        mapRegion = MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: long),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    }
                }
            }
        }
    }
    
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)
            
            VStack(spacing: 16) {
                content()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
            )
        }
    }
    
    private func createEvent() {
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let event = try await communityService.createEvent(
                    clubId: club.id,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    eventDescription: eventDescription.isEmpty ? nil : eventDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTime: startDate,
                    locationLat: selectedLocation?.latitude,
                    locationLong: selectedLocation?.longitude,
                    addressText: addressText.isEmpty ? nil : addressText,
                    meetingPointDescription: meetingPointDescription.isEmpty ? nil : meetingPointDescription,
                    requiredWeight: nil,
                    waterRequirements: nil
                )
                
                onEventCreated?(event)
                dismiss()
                
            } catch {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
    
    private func saveEventChanges() {
        guard let event = existingEvent else { return }
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let updates = CreateEventInput(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    eventDescription: eventDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTime: startDate,
                    locationLat: selectedLocation?.latitude,
                    locationLong: selectedLocation?.longitude,
                    addressText: addressText,
                    meetingPointDescription: meetingPointDescription,
                    requiredWeight: nil,
                    waterRequirements: ""
                )
                let updated = try await communityService.updateEvent(eventId: event.id, updates: updates)
                await MainActor.run {
                    onEventUpdated?(updated)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Dark Text Field Style

struct DarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(AppColors.surfaceAlt)
            .cornerRadius(12)
            .foregroundColor(AppColors.textPrimary)
    }
}

// MARK: - One-shot current location fetcher for map picker

private final class CurrentLocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    /// Toggles when a location fix arrives (used as an Equatable trigger for .onChange)
    @Published var locationReceived: Bool = false
    /// The resolved coordinate (read after locationReceived changes)
    var currentCoordinate: CLLocationCoordinate2D?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func fetchOnce() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // Will retry after authorization in didChangeAuthorization
            return
        case .denied, .restricted:
            currentCoordinate = nil
            return
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        @unknown default:
            currentCoordinate = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coord = location.coordinate
        Task { @MainActor in
            self.currentCoordinate = coord
            self.locationReceived.toggle()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.currentCoordinate = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            } else {
                self.currentCoordinate = nil
            }
        }
    }
}

// MARK: - Map Location Picker

struct MapLocationPicker: View {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss

    @StateObject private var locationFetcher = CurrentLocationFetcher()
    @State private var pinLocation: CLLocationCoordinate2D?
    @State private var hasAppliedInitialLocation = false

    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region, annotationItems: annotations) { item in
                    MapMarker(coordinate: item.coordinate, tint: .red)
                }
                .ignoresSafeArea(edges: .bottom)
                .onTapGesture { location in
                    // Note: This is a simplified approach
                    // For production, you'd use UIKit gesture recognizer
                }

                // Center pin indicator
                VStack {
                    Spacer()
                    Image(systemName: "mappin")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.accentWarm)
                    Spacer()
                }

                // Instructions
                VStack {
                    Text("Drag map to position pin")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.overlayBlack)
                        .cornerRadius(8)
                        .padding(.top, 16)

                    Spacer()
                }
            }
            .navigationTitle("Set Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        selectedLocation = region.center
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if selectedLocation == nil, !hasAppliedInitialLocation {
                    locationFetcher.fetchOnce()
                }
            }
            .onChange(of: locationFetcher.locationReceived) { _ in
                guard let coord = locationFetcher.currentCoordinate, selectedLocation == nil, !hasAppliedInitialLocation else { return }
                hasAppliedInitialLocation = true
                region = MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                selectedLocation = coord
            }
        }
    }

    private var annotations: [MapAnnotationItem] {
        if let loc = pinLocation {
            return [MapAnnotationItem(coordinate: loc)]
        }
        return []
    }
}

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
