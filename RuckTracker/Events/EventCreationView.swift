//
//  EventCreationView.swift
//  MARCH
//
//  Event creation form for Leaders and Founders
//  Part of the "Tribe Command" v2.0 update
//

import SwiftUI
import MapKit

struct EventCreationView: View {
    let club: Club
    let onEventCreated: ((ClubEvent) -> Void)?
    
    @StateObject private var communityService = CommunityService.shared
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var title = ""
    @State private var startDate = Date().addingTimeInterval(24 * 60 * 60)
    @State private var addressText = ""
    @State private var meetingPointDescription = ""
    @State private var requiredWeight: String = ""
    @State private var waterRequirements = ""
    
    // Map state
    @State private var showingMapPicker = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // UI state
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    init(club: Club, onEventCreated: ((ClubEvent) -> Void)? = nil) {
        self.club = club
        self.onEventCreated = onEventCreated
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        startDate > Date()
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
                                Text("Date & Time")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                DatePicker(
                                    "Start Time",
                                    selection: $startDate,
                                    in: Date()...,
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
                        
                        // Gear Check
                        formSection(title: "Gear Check") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Required Weight (lbs)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                TextField("30", text: $requiredWeight)
                                    .textFieldStyle(DarkTextFieldStyle())
                                    .keyboardType(.numberPad)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Water Requirements")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                
                                TextField("Bring 2L minimum", text: $waterRequirements)
                                    .textFieldStyle(DarkTextFieldStyle())
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
                        
                        // Create Button
                        Button(action: createEvent) {
                            if isCreating {
                                ProgressView()
                                    .tint(AppColors.textOnLight)
                            } else {
                                Text("Create Event")
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
            .navigationTitle("Create Event")
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
                let weight = Int(requiredWeight)
                
                let event = try await communityService.createEvent(
                    clubId: club.id,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTime: startDate,
                    locationLat: selectedLocation?.latitude,
                    locationLong: selectedLocation?.longitude,
                    addressText: addressText.isEmpty ? nil : addressText,
                    meetingPointDescription: meetingPointDescription.isEmpty ? nil : meetingPointDescription,
                    requiredWeight: weight,
                    waterRequirements: waterRequirements.isEmpty ? nil : waterRequirements
                )
                
                onEventCreated?(event)
                dismiss()
                
            } catch {
                errorMessage = error.localizedDescription
                isCreating = false
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

// MARK: - Map Location Picker

struct MapLocationPicker: View {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss
    
    @State private var pinLocation: CLLocationCoordinate2D?
    
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
