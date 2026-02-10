//
//  ClubMembersView.swift
//  MARCH
//
//  Member management view for club founders
//  Part of the "Tribe Command" v2.0 update
//

import SwiftUI

struct ClubMembersView: View {
    let club: Club
    let userRole: ClubRole
    
    @StateObject private var communityService = CommunityService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = true
    @State private var selectedMember: ClubMemberDetails?
    @State private var showingMemberActions = false
    @State private var showingEmergencyContact = false
    @State private var showingShareInvite = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .tint(AppColors.primary)
                        Text("Loading members...")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, 8)
                    }
                } else {
                    membersListView
                }
            }
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .sheet(isPresented: $showingMemberActions) {
                if let member = selectedMember {
                    MemberActionsSheet(
                        member: member,
                        club: club,
                        userRole: userRole,
                        onAction: { action in
                            handleMemberAction(action, for: member)
                        },
                        onShowEmergencyContact: {
                            showingEmergencyContact = true
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showingEmergencyContact) {
                if let member = selectedMember {
                    EmergencyContactView(member: member, club: club)
                        .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showingShareInvite) {
                ShareInviteSheet(club: club, joinCode: club.joinCode)
            }
        }
        .task {
            await loadMembers()
        }
    }
    
    // MARK: - Members List
    
    private var membersListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Club info header
                VStack(spacing: 8) {
                    Text("\(communityService.clubMembers.count)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(AppColors.primary)
                    
                    Text("Members")
                        .font(.system(size: 17))
                        .foregroundColor(AppColors.textSecondary)
                    
                    // Join code (for leaders and founders)
                    if userRole.canInviteMembers {
                        HStack(spacing: 8) {
                            Text("Join Code:")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text(club.joinCode)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(AppColors.primary)
                            
                            Button(action: copyJoinCode) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.primary)
                            }
                            
                            Button(action: { showingShareInvite = true }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.surface)
                )
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accentWarm)
                        .padding()
                }
                
                // Members grouped by role (id forces SwiftUI to refresh when roles change)
                memberSection(title: "Founders", members: membersWithRole(.founder))
                memberSection(title: "Leaders", members: membersWithRole(.leader))
                memberSection(title: "Members", members: membersWithRole(.member))
            }
            .padding()
            .id(membersListIdentity)
        }
    }
    
    /// Identity that changes when member roles change so the list view refreshes
    private var membersListIdentity: String {
        let parts = communityService.clubMembers.map { "\($0.userId.uuidString.prefix(8))=\($0.role.rawValue)" }
        return parts.joined(separator: "|")
    }
    
    private func memberSection(title: String, members: [ClubMemberDetails]) -> some View {
        Group {
            if !members.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(1)
                    
                    VStack(spacing: 1) {
                        ForEach(members) { member in
                            memberRow(member: member)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.surface)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
    
    private func memberRow(member: ClubMemberDetails) -> some View {
        Button(action: {
            selectedMember = member
            showingMemberActions = true
        }) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(roleColor(member.role).opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(member.username?.prefix(1).uppercased() ?? "?")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(roleColor(member.role))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.username ?? "Unknown")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    
                    HStack(spacing: 8) {
                        // Role badge
                        Text(member.role.displayText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(roleColor(member.role))
                        
                        // Waiver status
                        if member.hasSignedWaiver {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 10))
                                Text("Waiver")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(AppColors.successGreen)
                        }
                    }
                }
                
                Spacer()
                
                // Show chevron when viewing another member (any role can tap to view) or when user can manage this member
                if member.userId != communityService.currentProfile?.id || (userRole.canManageMembers && member.role != .founder) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding()
            .background(AppColors.surface)
        }
        .buttonStyle(.plain)
    }
    
    private func membersWithRole(_ role: ClubRole) -> [ClubMemberDetails] {
        communityService.clubMembers.filter { $0.role == role }
    }
    
    private func roleColor(_ role: ClubRole) -> Color {
        switch role {
        case .founder: return AppColors.accentWarm
        case .leader: return AppColors.primary
        case .member: return AppColors.textSecondary
        }
    }
    
    // MARK: - Actions
    
    private func loadMembers() async {
        isLoading = true
        do {
            try await communityService.loadClubMembers(clubId: club.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func copyJoinCode() {
        UIPasteboard.general.string = club.joinCode
    }
    
    private func handleMemberAction(_ action: MemberAction, for member: ClubMemberDetails) {
        errorMessage = nil
        
        Task {
            do {
                switch action {
                case .promoteToLeader:
                    try await communityService.promoteToLeader(userId: member.userId, clubId: club.id)
                case .demoteToMember:
                    try await communityService.demoteToMember(userId: member.userId, clubId: club.id)
                case .removeMember:
                    try await communityService.removeMember(userId: member.userId, clubId: club.id)
                }
                await loadMembers()
                selectedMember = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Member Action

enum MemberAction {
    case promoteToLeader
    case demoteToMember
    case removeMember
}

// MARK: - Member Actions Sheet

struct MemberActionsSheet: View {
    let member: ClubMemberDetails
    let club: Club
    let userRole: ClubRole
    let onAction: (MemberAction) -> Void
    let onShowEmergencyContact: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingRemoveConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Member info
                    VStack(spacing: 12) {
                        Circle()
                            .fill(AppColors.primary.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(member.username?.prefix(1).uppercased() ?? "?")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(AppColors.primary)
                            )
                        
                        Text(member.username ?? "Unknown")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text(member.role.displayText)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textSecondary)
                        
                        if member.hasSignedWaiver {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                Text("Waiver Signed")
                            }
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.successGreen)
                        }
                    }
                    
                    if member.role != .founder {
                        VStack(spacing: 12) {
                            // View emergency contact (founder + leader) – show for any non-founder member;
                            // detail view will show contact or "No emergency contact on file" (waiver is per-club).
                            if userRole.canViewEmergencyData {
                                actionButton(
                                    title: "View Emergency Contact",
                                    icon: "phone.circle.fill",
                                    color: AppColors.primary,
                                    action: {
                                        onShowEmergencyContact()
                                        dismiss()
                                    }
                                )
                            }
                            
                            // Promote/Demote (founder only)
                            if userRole.canManageMembers {
                                if member.role == .member {
                                    actionButton(
                                        title: "Promote to Leader",
                                        icon: "arrow.up.circle.fill",
                                        color: AppColors.successGreen,
                                        action: {
                                            onAction(.promoteToLeader)
                                            dismiss()
                                        }
                                    )
                                } else if member.role == .leader {
                                    actionButton(
                                        title: "Demote to Member",
                                        icon: "arrow.down.circle.fill",
                                        color: AppColors.pauseOrange,
                                        action: {
                                            onAction(.demoteToMember)
                                            dismiss()
                                        }
                                    )
                                }
                            }
                            
                            // Remove member (founder + leader)
                            if userRole.canRemoveMembers {
                                actionButton(
                                    title: "Remove from Club",
                                    icon: "person.crop.circle.badge.minus",
                                    color: AppColors.destructiveRed,
                                    action: { showingRemoveConfirmation = true }
                                )
                            }
                        }
                    } else if member.role == .founder {
                        Text("Founders cannot be modified")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .alert("Remove Member", isPresented: $showingRemoveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    onAction(.removeMember)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to remove \(member.username ?? "this member") from the club?")
            }
        }
    }
    
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.surface)
            )
        }
    }
}

// MARK: - Emergency Contact View

struct EmergencyContactView: View {
    let member: ClubMemberDetails
    let club: Club
    
    @StateObject private var communityService = CommunityService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var emergencyContact: EmergencyContact?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "phone.badge.waveform.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.primary)
                    
                    Text("Emergency Contact")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("For \(member.username ?? "Unknown")")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                    
                    if isLoading {
                        ProgressView()
                            .tint(AppColors.primary)
                    } else if let contact = emergencyContact {
                        VStack(spacing: 16) {
                            contactRow(label: "Name", value: contact.name)
                            contactRow(label: "Phone", value: contact.phone, isPhone: true)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.surface)
                        )
                        
                        // Call button
                        if let phoneURL = URL(string: "tel:\(contact.phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: ""))") {
                            Link(destination: phoneURL) {
                                HStack {
                                    Image(systemName: "phone.fill")
                                    Text("Call Now")
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppColors.textOnLight)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.successGreen)
                                .cornerRadius(12)
                            }
                        }
                    } else {
                        Text("No emergency contact on file")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding()
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
        }
        .task {
            await loadEmergencyContact()
        }
    }
    
    private func contactRow(label: String, value: String, isPhone: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)
            
            Text(value)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isPhone ? AppColors.primary : AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func loadEmergencyContact() async {
        isLoading = true
        do {
            emergencyContact = try await communityService.getMemberEmergencyContact(userId: member.userId, clubId: club.id)
        } catch {
            print("❌ Failed to load emergency contact: \(error)")
        }
        isLoading = false
    }
}
