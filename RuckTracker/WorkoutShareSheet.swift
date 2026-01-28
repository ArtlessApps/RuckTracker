import SwiftUI
import UIKit

struct WorkoutShareData {
    let title: String
    let distanceMiles: Double
    let durationSeconds: TimeInterval
    let calories: Int
    let ruckWeight: Int
    let elevationGain: Int
    let date: Date
    let workoutURI: URL?
    
    // v2.0: Club context for "Propaganda Mode"
    var clubName: String? = nil
    
    init(title: String, distanceMiles: Double, durationSeconds: TimeInterval, calories: Int, ruckWeight: Int, elevationGain: Int = 0, date: Date, workoutURI: URL?, clubName: String? = nil) {
        self.title = title
        self.distanceMiles = distanceMiles
        self.durationSeconds = durationSeconds
        self.calories = calories
        self.ruckWeight = ruckWeight
        self.elevationGain = elevationGain
        self.date = date
        self.workoutURI = workoutURI
        self.clubName = clubName
    }
}

/// Share experience shown after completing a workout or from history.
struct WorkoutShareSheet: View {
    let data: WorkoutShareData
    
    @StateObject private var premiumManager = PremiumManager.shared
    
    @State private var includeCalories = true
    @State private var includeWeight = true
    @State private var includeElevation = true
    @State private var includeLink = true
    @State private var useSquareFormat = false
    @State private var generatedImage: UIImage?
    @State private var isGenerating = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var toastMessage: String?
    @State private var customCaption: String = ""
    
    // v2.0: Propaganda Mode (Pro only)
    @State private var showTonnage = true
    @State private var showClubBadge = true
    @State private var showingPaywall = false
    
    private let renderer = ShareCardRenderer()
    
    /// Whether user has access to Propaganda Mode features
    private var hasPropagandaMode: Bool {
        premiumManager.isPremiumUser
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                if let image = generatedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                } else if isGenerating {
                    ProgressView("Building your share card...")
                } else {
                    Text("Generate a share card with your ruck stats.")
                        .foregroundColor(AppColors.textSecondary)
                }
                
                // Basic Toggles
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show calories", isOn: $includeCalories)
                    Toggle("Show ruck weight", isOn: $includeWeight)
                    Toggle("Show elevation", isOn: $includeElevation)
                    Toggle("Include app link", isOn: $includeLink)
                    Toggle("Square format (Feed)", isOn: $useSquareFormat)
                }
                .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                .padding()
                .background(AppColors.surfaceAlt)
                .cornerRadius(12)
                
                // Propaganda Mode (Pro)
                propagandaModeSection
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Caption")
                        .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    TextEditor(text: $customCaption)
                        .frame(height: 80)
                        .padding(8)
                    .background(AppColors.surfaceAlt)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.accentWarm.opacity(0.15), lineWidth: 1)
                        )
                }
                
                VStack(spacing: 12) {
                    Button {
                        Task { await shareToInstagram() }
                    } label: {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("Share to Instagram Story")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(generatedImage == nil)
                    
                    Button {
                        Task { await shareToSystemSheet() }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share or Save")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(generatedImage == nil)
                    
                    Button {
                        UIPasteboard.general.string = captionText
                        toastMessage = "Caption copied"
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy caption")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Share your ruck")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Regenerate") {
                        Task { await generateCard() }
                    }
                    .disabled(isGenerating)
                }
            }
            .onAppear {
                DebugLogger.shared.log("📲 Share: share sheet opened")
                Task { await generateCard() }
                customCaption = shareCaption(channel: "copy")
            }
            .onChange(of: includeCalories) { _, _ in
                Task { await generateCard() }
                customCaption = shareCaption(channel: "copy")
            }
            .onChange(of: includeWeight) { _, _ in
                Task { await generateCard() }
                customCaption = shareCaption(channel: "copy")
            }
            .onChange(of: includeElevation) { _, _ in
                Task { await generateCard() }
                customCaption = shareCaption(channel: "copy")
            }
            .onChange(of: includeLink) { _, _ in
                Task { await generateCard() }
                customCaption = shareCaption(channel: "copy")
            }
            .onChange(of: useSquareFormat) { _, _ in
                Task { await generateCard() }
            }
            .onChange(of: showTonnage) { _, _ in
                Task { await generateCard() }
            }
            .onChange(of: showClubBadge) { _, _ in
                Task { await generateCard() }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareItems)
            }
            .overlay(alignment: .bottom) {
                if let toastMessage = toastMessage {
                    Text(toastMessage)
                        .font(.footnote)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColors.overlayBlackSemi)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.bottom, 20)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                self.toastMessage = nil
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Propaganda Mode Section
    
    @ViewBuilder
    private var propagandaModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PROPAGANDA MODE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
                    .tracking(1)
                
                Spacer()
                
                if hasPropagandaMode {
                    PremiumBadge(size: .small)
                } else {
                    LockedFeatureBadge(feature: .propagandaMode)
                }
            }
            
            if hasPropagandaMode {
                // Pro user - show toggles
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $showTonnage) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Tonnage")
                            Text("Hero metric: Weight × Distance")
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    if let clubName = data.clubName, !clubName.isEmpty {
                        Toggle(isOn: $showClubBadge) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Club Badge")
                                Text("TRAINING WITH \(clubName.uppercased())")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
            } else {
                // Free user - show upsell
                Button(action: { showingPaywall = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unlock Propaganda Mode")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Massive tonnage overlay, club badge, military-stencil theme")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(hasPropagandaMode ? AppColors.primary.opacity(0.1) : AppColors.surfaceAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(hasPropagandaMode ? AppColors.primary.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .sheet(isPresented: $showingPaywall) {
            SubscriptionPaywallView(context: .featureUpsell)
        }
    }
    
    // MARK: - Actions
    
    private func generateCard() async {
        isGenerating = true
        
        // Determine which Pro features to include
        let includeTonnage = hasPropagandaMode && showTonnage
        let includeClubName = hasPropagandaMode && showClubBadge ? data.clubName : nil
        
        let payload = ShareCardPayload(
            title: data.title,
            distanceMiles: data.distanceMiles,
            durationSeconds: data.durationSeconds,
            calories: data.calories,
            ruckWeight: data.ruckWeight,
            elevationGain: data.elevationGain,
            date: data.date,
            showCalories: includeCalories,
            showWeight: includeWeight,
            showElevation: includeElevation,
            shareURL: includeLink ? shareURL(channel: "preview") : nil,
            clubName: includeClubName,
            showTonnage: includeTonnage
        )
        let format: ShareCardFormat = useSquareFormat ? .square : .story
        generatedImage = await renderer.render(payload: payload, format: format)
        isGenerating = false
    }
    
    private func shareURL(channel: String) -> URL? {
        ShareLinkBuilder.makeShareURL(workoutURI: data.workoutURI, channel: channel)
    }
    
    private func shareCaption(channel: String) -> String {
        let paceString: String = {
            guard data.distanceMiles > 0 else { return "--:--" }
            let pace = data.durationSeconds / data.distanceMiles
            let minutes = Int(pace) / 60
            let seconds = Int(pace) % 60
            return String(format: "%d:%02d/mi", minutes, seconds)
        }()
        
        var parts: [String] = []
        parts.append("Crushed a \(String(format: "%.2f", data.distanceMiles)) mi ruck in \(formattedTime())")
        
        // Pro feature: Show tonnage in caption
        if hasPropagandaMode && showTonnage && data.ruckWeight > 0 && data.distanceMiles > 0 {
            let tonnage = Double(data.ruckWeight) * data.distanceMiles
            parts.append(String(format: "%.0f lb-mi tonnage", tonnage))
        } else if includeWeight {
            parts.append("\(Int(data.ruckWeight)) lbs")
        }
        
        if includeElevation && data.elevationGain > 0 {
            parts.append("↑\(data.elevationGain) ft")
        }
        if includeCalories {
            parts.append("\(data.calories) kcal")
        }
        parts.append("Pace \(paceString)")
        
        var caption = parts.joined(separator: " • ")
        
        // Pro feature: Add club badge mention
        if hasPropagandaMode && showClubBadge, let clubName = data.clubName, !clubName.isEmpty {
            caption += " | Training with \(clubName)"
        }
        
        if includeLink, let url = shareURL(channel: channel) {
            caption += " – \(url.absoluteString)"
        }
        return caption
    }
    
    private var captionText: String {
        customCaption.isEmpty ? shareCaption(channel: "copy") : customCaption
    }
    
    private func formattedTime() -> String {
        let total = Int(data.durationSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func shareToInstagram() async {
        guard let image = generatedImage else { return }
        guard let urlScheme = URL(string: "instagram-stories://share") else { return }
        
        if !UIApplication.shared.canOpenURL(urlScheme) {
            toastMessage = "Instagram not installed—use Share instead."
            await shareToSystemSheet()
            return
        }
        
        var items: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": image
        ]
        if includeLink, let link = shareURL(channel: "instagram_story") {
            items["com.instagram.sharedSticker.contentURL"] = link.absoluteString
        }
        
        UIPasteboard.general.setItems([items], options: [:])
        _ = await UIApplication.shared.open(urlScheme, options: [:])
        DebugLogger.shared.log("📲 Share: Instagram Story initiated | link=\(includeLink) | format=\(useSquareFormat ? "square" : "story")")
    }
    
    private func shareToSystemSheet() async {
        guard let image = generatedImage else { return }
        var items: [Any] = [image, captionText]
        if includeLink, let link = shareURL(channel: "share_sheet") {
            items.append(link)
        }
        shareItems = items
        showingShareSheet = true
        DebugLogger.shared.log("📲 Share: System sheet opened | link=\(includeLink) | format=\(useSquareFormat ? "square" : "story")")
    }
}

