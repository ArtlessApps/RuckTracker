//
//  ClubSettingsView.swift
//  MARCH
//
//  Founder-only club management settings:
//  - Edit club details
//  - Share/invite members
//  - Regenerate join code
//  - Transfer ownership
//  - Delete club
//

import SwiftUI

struct ClubSettingsView: View {
    let club: Club
    
    @StateObject private var communityService = CommunityService.shared
    @Environment(\.dismiss) private var dismiss
    
    // Edit states
    @State private var editedName: String = ""
    @State private var editedDescription: String = ""
    @State private var editedZipcode: String = ""
    @State private var editedIsPrivate: Bool = false
    @State private var hasUnsavedChanges: Bool = false
    
    // Sheet states
    @State private var showingTransferSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingRegenerateConfirmation = false
    @State private var showingShareSheet = false
    @State private var showingSaveConfirmation = false
    @State private var showingDiscardConfirmation = false
    
    // Action states
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var isRegenerating = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    // Current join code (may change after regeneration)
    @State private var currentJoinCode: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Error/Success messages
                        if let error = errorMessage {
                            MessageBanner(message: error, type: .error)
                        }
                        
                        if let success = successMessage {
                            MessageBanner(message: success, type: .success)
                        }
                        
                        // Edit Club Details Section
                        editDetailsSection
                        
                        // Invite & Share Section
                        inviteSection
                        
                        // Danger Zone Section
                        dangerZoneSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Club Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showingDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(hasUnsavedChanges ? AppColors.primary : AppColors.textSecondary)
                    .disabled(!hasUnsavedChanges || isSaving)
                }
            }
            .sheet(isPresented: $showingTransferSheet) {
                TransferOwnershipSheet(club: club, onTransferred: {
                    dismiss()
                })
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareInviteSheet(club: club, joinCode: currentJoinCode)
            }
            .alert("Delete Club", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Forever", role: .destructive) {
                    deleteClub()
                }
            } message: {
                Text("This will permanently delete \"\(club.name)\" and all its data including posts, events, and member history. This cannot be undone.")
            }
            .alert("Regenerate Join Code", isPresented: $showingRegenerateConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Regenerate", role: .destructive) {
                    regenerateCode()
                }
            } message: {
                Text("This will invalidate the current join code. Anyone with the old code will no longer be able to join. Share the new code with your members.")
            }
            .alert("Discard Changes?", isPresented: $showingDiscardConfirmation) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
        }
        .onAppear {
            // Initialize with current club values
            editedName = club.name
            editedDescription = club.description ?? ""
            editedZipcode = club.zipcode ?? ""
            editedIsPrivate = club.isPrivate
            currentJoinCode = club.joinCode
        }
        .onChange(of: editedName) { _ in checkForChanges() }
        .onChange(of: editedDescription) { _ in checkForChanges() }
        .onChange(of: editedZipcode) { _ in checkForChanges() }
        .onChange(of: editedIsPrivate) { _ in checkForChanges() }
    }
    
    // MARK: - Edit Details Section
    
    private var editDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Club Details", icon: "pencil.circle.fill")
            
            VStack(spacing: 16) {
                // Club Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Club Name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    
                    TextField("Club Name", text: $editedName)
                        .padding(10)
                        .background(AppColors.surfaceAlt)
                        .cornerRadius(8)
                }
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    
                    TextEditor(text: $editedDescription)
                        .frame(height: 80)
                        .padding(4)
                        .scrollContentBackground(.hidden)
                        .background(AppColors.surfaceAlt)
                        .cornerRadius(8)
                }
                
                // Zipcode
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location (Zipcode)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    
                    TextField("92101", text: $editedZipcode)
                        .padding(10)
                        .background(AppColors.surfaceAlt)
                        .cornerRadius(8)
                        .keyboardType(.numberPad)
                }
                
                // Privacy Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Private Club")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text(editedIsPrivate ? "Only visible with invite code" : "Visible in club search")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $editedIsPrivate)
                        .labelsHidden()
                        .tint(AppColors.primary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
            )
        }
    }
    
    // MARK: - Invite Section
    
    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Invite Members", icon: "person.badge.plus")
            
            VStack(spacing: 1) {
                // Current Join Code
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Join Code")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text(currentJoinCode)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.primary)
                    }
                    
                    Spacer()
                    
                    Button(action: copyJoinCode) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.primary)
                    }
                }
                .padding()
                .background(AppColors.surface)
                
                Divider()
                    .background(AppColors.backgroundGradient)
                
                // Share Invite
                settingsButton(
                    title: "Share Invite",
                    subtitle: "Send invite via email, message, or social",
                    icon: "square.and.arrow.up",
                    color: AppColors.primary,
                    action: { showingShareSheet = true }
                )
                
                Divider()
                    .background(AppColors.backgroundGradient)
                
                // Regenerate Code
                settingsButton(
                    title: "Regenerate Join Code",
                    subtitle: "Invalidate current code and create a new one",
                    icon: "arrow.triangle.2.circlepath",
                    color: AppColors.pauseOrange,
                    isLoading: isRegenerating,
                    action: { showingRegenerateConfirmation = true }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Danger Zone Section
    
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Danger Zone", icon: "exclamationmark.triangle.fill", color: AppColors.destructiveRed)
            
            VStack(spacing: 1) {
                // Transfer Ownership
                settingsButton(
                    title: "Transfer Ownership",
                    subtitle: "Pass founder role to another member",
                    icon: "person.2.badge.gearshape",
                    color: AppColors.pauseOrange,
                    action: { showingTransferSheet = true }
                )
                
                Divider()
                    .background(AppColors.backgroundGradient)
                
                // Delete Club
                settingsButton(
                    title: "Delete Club",
                    subtitle: "Permanently delete this club and all data",
                    icon: "trash.fill",
                    color: AppColors.destructiveRed,
                    isLoading: isDeleting,
                    action: { showingDeleteConfirmation = true }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String, color: Color = AppColors.primary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)
        }
    }
    
    private func settingsButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .tint(color)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding()
            .background(AppColors.surface)
        }
        .disabled(isLoading)
    }
    
    // MARK: - Actions
    
    private func checkForChanges() {
        hasUnsavedChanges = editedName != club.name ||
            editedDescription != (club.description ?? "") ||
            editedZipcode != (club.zipcode ?? "") ||
            editedIsPrivate != club.isPrivate
    }
    
    private func saveChanges() {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                try await communityService.updateClub(
                    clubId: club.id,
                    name: editedName != club.name ? editedName : nil,
                    description: editedDescription != (club.description ?? "") ? editedDescription : nil,
                    isPrivate: editedIsPrivate != club.isPrivate ? editedIsPrivate : nil,
                    zipcode: editedZipcode != (club.zipcode ?? "") ? editedZipcode : nil
                )
                
                successMessage = "Club settings saved!"
                hasUnsavedChanges = false
                
                // Clear success message after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    successMessage = nil
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
    
    private func copyJoinCode() {
        UIPasteboard.general.string = currentJoinCode
        successMessage = "Join code copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            successMessage = nil
        }
    }
    
    private func regenerateCode() {
        isRegenerating = true
        errorMessage = nil
        
        Task {
            do {
                let newCode = try await communityService.regenerateJoinCode(clubId: club.id)
                currentJoinCode = newCode
                successMessage = "New join code generated!"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    successMessage = nil
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isRegenerating = false
        }
    }
    
    private func deleteClub() {
        isDeleting = true
        errorMessage = nil
        
        Task {
            do {
                try await communityService.deleteClub(clubId: club.id)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isDeleting = false
            }
        }
    }
}

// MARK: - Message Banner

struct MessageBanner: View {
    let message: String
    let type: MessageType
    
    enum MessageType {
        case success
        case error
        
        var color: Color {
            switch self {
            case .success: return AppColors.successGreen
            case .error: return AppColors.destructiveRed
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(type.color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(type.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Transfer Ownership Sheet

struct TransferOwnershipSheet: View {
    let club: Club
    let onTransferred: () -> Void
    
    @StateObject private var communityService = CommunityService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMember: ClubMemberDetails?
    @State private var isLoading = true
    @State private var isTransferring = false
    @State private var showingConfirmation = false
    @State private var errorMessage: String?
    
    var eligibleMembers: [ClubMemberDetails] {
        communityService.clubMembers.filter { $0.role != .founder }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.badge.gearshape.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.pauseOrange)
                        
                        Text("Transfer Ownership")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Select a member to become the new founder. You will become a leader.")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    if let error = errorMessage {
                        MessageBanner(message: error, type: .error)
                            .padding(.horizontal)
                    }
                    
                    if isLoading {
                        ProgressView()
                            .tint(AppColors.primary)
                        Spacer()
                    } else if eligibleMembers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 36))
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text("No members to transfer to")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text("Invite members to your club first.")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.top, 32)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(eligibleMembers) { member in
                                    MemberSelectionRow(
                                        member: member,
                                        isSelected: selectedMember?.id == member.id,
                                        onTap: { selectedMember = member }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Transfer button
                        Button(action: { showingConfirmation = true }) {
                            if isTransferring {
                                ProgressView()
                                    .tint(AppColors.textOnLight)
                            } else {
                                Text("Transfer Ownership")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(selectedMember == nil || isTransferring)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .alert("Confirm Transfer", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Transfer", role: .destructive) {
                    transferOwnership()
                }
            } message: {
                if let member = selectedMember {
                    Text("Are you sure you want to make \(member.username ?? "this member") the new founder? You will become a leader and lose founder privileges.")
                }
            }
        }
        .task {
            await loadMembers()
        }
    }
    
    private func loadMembers() async {
        isLoading = true
        do {
            try await communityService.loadClubMembers(clubId: club.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func transferOwnership() {
        guard let member = selectedMember else { return }
        
        isTransferring = true
        errorMessage = nil
        
        Task {
            do {
                try await communityService.transferFoundership(clubId: club.id, newFounderId: member.userId)
                dismiss()
                onTransferred()
            } catch {
                errorMessage = error.localizedDescription
                isTransferring = false
            }
        }
    }
}

struct MemberSelectionRow: View {
    let member: ClubMemberDetails
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(AppColors.primary.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(member.username?.prefix(1).uppercased() ?? "?")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.username ?? "Unknown")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(member.role.displayText)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Share Invite Sheet

struct ShareInviteSheet: View {
    let club: Club
    let joinCode: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingActivitySheet = false
    
    private var inviteMessage: String {
        """
        Join my rucking club "\(club.name)" on MARCH!
        
        Use join code: \(joinCode)
        
        Download MARCH and enter the code in the Tribe tab to join.
        """
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 36))
                                .foregroundColor(AppColors.primary)
                        }
                        
                        Text("Invite to \(club.name)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    // Join Code Card
                    VStack(spacing: 12) {
                        Text("Join Code")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(joinCode)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.primary)
                        
                        Button(action: copyCode) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Code")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.primary)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.surface)
                    )
                    .padding(.horizontal)
                    
                    // Share Options
                    VStack(spacing: 12) {
                        // Share via system sheet
                        Button(action: { showingActivitySheet = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Invite")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.textOnLight)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.primary)
                            .cornerRadius(12)
                        }
                        
                        // Copy full message
                        Button(action: copyFullMessage) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Invite Message")
                            }
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppColors.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.primary, lineWidth: 1.5)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Preview of message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invite Message Preview")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(inviteMessage)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.surface)
                            )
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.top, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .sheet(isPresented: $showingActivitySheet) {
                ActivityViewController(activityItems: [inviteMessage])
            }
        }
    }
    
    private func copyCode() {
        UIPasteboard.general.string = joinCode
    }
    
    private func copyFullMessage() {
        UIPasteboard.general.string = inviteMessage
    }
}

// MARK: - Activity View Controller (Share Sheet)

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
