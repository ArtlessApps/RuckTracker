//
//  WaiverOnboardingSheet.swift
//  MARCH
//
//  Waiver system: Safety Briefing, Emergency Contact, Digital Signature
//  Part of the "Tribe Command" v2.0 update
//

import SwiftUI

struct WaiverOnboardingSheet: View {
    let clubId: UUID
    let clubName: String
    let onWaiverSigned: () -> Void
    
    @StateObject private var communityService = CommunityService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep: WaiverStep = .safetyBriefing
    @State private var hasScrolledToBottom = false
    @State private var emergencyContactName = ""
    @State private var emergencyContactPhone = ""
    @State private var hasSigned = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    enum WaiverStep: Int, CaseIterable {
        case safetyBriefing = 1
        case emergencyContact = 2
        case signature = 3
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    progressBar
                    
                    // Content
                    switch currentStep {
                    case .safetyBriefing:
                        safetyBriefingView
                    case .emergencyContact:
                        emergencyContactView
                    case .signature:
                        signatureView
                    }
                }
            }
            .navigationTitle("Safety Waiver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep != .safetyBriefing {
                        Button(action: goBack) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(WaiverStep.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue ? AppColors.primary : AppColors.surface)
                    .frame(height: 4)
            }
        }
        .padding()
    }
    
    // MARK: - Step 1: Safety Briefing
    
    private var safetyBriefingView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.primary)
                
                Text("Safety Briefing")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Please read the following carefully")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.top)
            
            // Scrollable safety text
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        safetySection(title: "Physical Activity Warning", content: """
                            Rucking is a physically demanding activity. By participating in club events, you acknowledge that you are voluntarily engaging in physical exercise that may result in injury.
                            
                            Before participating, ensure you:
                            • Have consulted with a physician if you have any health concerns
                            • Are properly hydrated and nourished
                            • Have appropriate footwear and equipment
                            • Know your physical limits
                            """)
                        
                        safetySection(title: "Assumption of Risk", content: """
                            You understand and accept that:
                            • Outdoor activities carry inherent risks including but not limited to: uneven terrain, weather conditions, traffic, and wildlife
                            • Club leaders are volunteers, not professional trainers
                            • You are responsible for your own safety and well-being
                            • You will follow the directions of club leaders
                            """)
                        
                        safetySection(title: "Release of Liability", content: """
                            By signing this waiver, you release and hold harmless \(clubName), its founders, leaders, members, and affiliates from any claims, damages, or injuries arising from your participation in club activities.
                            
                            This release applies to all club events, training sessions, and related activities.
                            """)
                        
                        safetySection(title: "Emergency Procedures", content: """
                            In case of emergency:
                            • Alert the nearest club leader immediately
                            • Call 911 if necessary
                            • Your emergency contact will be notified
                            
                            By providing emergency contact information, you authorize club leaders to contact them in case of emergency.
                            """)
                        
                        // End marker
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                            .onAppear {
                                hasScrolledToBottom = true
                            }
                    }
                    .padding()
                }
                .background(AppColors.surface)
                .cornerRadius(16)
                .onChange(of: currentStep) { _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            
            // Continue button
            Button(action: { currentStep = .emergencyContact }) {
                Text(hasScrolledToBottom ? "I've Read This" : "Scroll to Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textOnLight)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(hasScrolledToBottom ? AppColors.primary : AppColors.surface)
                    .cornerRadius(12)
            }
            .disabled(!hasScrolledToBottom)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private func safetySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppColors.primary)
                .tracking(1)
            
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)
                .lineSpacing(4)
        }
    }
    
    // MARK: - Step 2: Emergency Contact
    
    private var emergencyContactView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "phone.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.primary)
                
                Text("Emergency Contact")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Who should we contact in an emergency?")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.top)
            
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact Name")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    
                    TextField("John Smith", text: $emergencyContactName)
                        .textFieldStyle(DarkTextFieldStyle())
                        .textContentType(.name)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    
                    TextField("(555) 123-4567", text: $emergencyContactPhone)
                        .textFieldStyle(DarkTextFieldStyle())
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
            )
            
            Spacer()
            
            // Continue button
            Button(action: { currentStep = .signature }) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textOnLight)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isEmergencyContactValid ? AppColors.primary : AppColors.surface)
                    .cornerRadius(12)
            }
            .disabled(!isEmergencyContactValid)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.horizontal)
    }
    
    private var isEmergencyContactValid: Bool {
        !emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !emergencyContactPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Step 3: Signature
    
    private var signatureView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "signature")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.primary)
                
                Text("Digital Signature")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Tap to acknowledge and sign")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.top)
            
            // Summary
            VStack(alignment: .leading, spacing: 16) {
                Text("By signing, I acknowledge that:")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                checklistItem("I have read and understood the safety briefing")
                checklistItem("I accept the risks associated with rucking")
                checklistItem("I release the club from liability")
                checklistItem("I authorize emergency contact notification")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
            )
            
            // Signature box
            Button(action: { hasSigned.toggle() }) {
                VStack(spacing: 12) {
                    if hasSigned {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.successGreen)
                        
                        Text("Signed")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.successGreen)
                    } else {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text("Tap to Sign")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(hasSigned ? AppColors.successGreen : AppColors.textSecondary, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(hasSigned ? AppColors.successGreen.opacity(0.1) : AppColors.surface)
                        )
                )
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accentWarm)
            }
            
            Spacer()
            
            // Submit button
            Button(action: submitWaiver) {
                if isSubmitting {
                    ProgressView()
                        .tint(AppColors.textOnLight)
                } else {
                    Text("Complete & Join Club")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(AppColors.textOnLight)
            .frame(maxWidth: .infinity)
            .padding()
            .background(hasSigned ? AppColors.primary : AppColors.surface)
            .cornerRadius(12)
            .disabled(!hasSigned || isSubmitting)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.horizontal)
    }
    
    private func checklistItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.primary)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)
        }
    }
    
    // MARK: - Actions
    
    private func goBack() {
        switch currentStep {
        case .safetyBriefing:
            break
        case .emergencyContact:
            currentStep = .safetyBriefing
        case .signature:
            currentStep = .emergencyContact
        }
    }
    
    private func submitWaiver() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await communityService.signWaiver(
                    clubId: clubId,
                    emergencyContactName: emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines),
                    emergencyContactPhone: emergencyContactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                onWaiverSigned()
                dismiss()
                
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}
