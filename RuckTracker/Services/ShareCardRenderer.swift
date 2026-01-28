import SwiftUI
import UIKit

struct ShareCardPayload {
    let title: String
    let distanceMiles: Double
    let durationSeconds: TimeInterval
    let calories: Int
    let ruckWeight: Int
    let elevationGain: Int
    let date: Date
    let showCalories: Bool
    let showWeight: Bool
    let showElevation: Bool
    let shareURL: URL?
    
    // New v2.0 properties
    var clubName: String? = nil  // For "TRAINING WITH [CLUB NAME]" badge
    var showTonnage: Bool = true // Show tonnage as hero metric
    
    /// Calculate tonnage: Weight (lbs) × Distance (miles)
    var tonnage: Double {
        Double(ruckWeight) * distanceMiles
    }
    
    /// Formatted tonnage string
    var formattedTonnage: String {
        if tonnage >= 1000 {
            return String(format: "%.1fK", tonnage / 1000.0)
        } else {
            return String(format: "%.0f", tonnage)
        }
    }
}

enum ShareCardFormat {
    case story
    case square
    
    var size: CGSize {
        switch self {
        case .story:
            return CGSize(width: 1080, height: 1920)
        case .square:
            return CGSize(width: 1080, height: 1080)
        }
    }
}

/// Renders the workout share card to UIImage for social sharing.
final class ShareCardRenderer {
    func render(payload: ShareCardPayload, format: ShareCardFormat) async -> UIImage? {
        await MainActor.run {
            let view = ShareCardView(payload: payload, format: format)
            let renderer = ImageRenderer(content: view)
            renderer.scale = UIScreen.main.scale
            renderer.proposedSize = ProposedViewSize(
                width: format.size.width,
                height: format.size.height
            )
            return renderer.uiImage
        }
    }
}

private struct ShareCardView: View {
    let payload: ShareCardPayload
    let format: ShareCardFormat
    
    private var formattedDistance: String {
        String(format: "%.2f mi", payload.distanceMiles)
    }
    
    private var formattedTime: String {
        let total = Int(payload.durationSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private var formattedPace: String {
        guard payload.distanceMiles > 0 else { return "--:--" }
        let pace = payload.durationSeconds / payload.distanceMiles
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /mi", minutes, seconds)
    }
    
    private var formattedElevation: String {
        return "\(payload.elevationGain) ft"
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: payload.date)
    }
    
    var body: some View {
        ZStack {
            // Background gradient - military-inspired dark theme
            LinearGradient(
                colors: [AppColors.background, Color(hex: "0A1A2A"), AppColors.primary.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(payload.title.uppercased())
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(AppColors.textPrimary)
                            .tracking(2)
                        Text(formattedDate)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.75))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("MARCH")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(AppColors.primary)
                            .tracking(3)
                    }
                }
                
                // Hero Metrics Section
                if payload.showTonnage && payload.ruckWeight > 0 && payload.distanceMiles > 0 {
                    // Tonnage as hero metric
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TONNAGE")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.primary)
                            .tracking(2)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(payload.formattedTonnage)
                                .font(.system(size: 72, weight: .black))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("LB-MI")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppColors.textPrimary.opacity(0.6))
                        }
                    }
                    .padding(.vertical, 8)
                } else if payload.showWeight && payload.ruckWeight > 0 {
                    // Weight as hero metric if no tonnage
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WEIGHT")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.primary)
                            .tracking(2)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(payload.ruckWeight)")
                                .font(.system(size: 72, weight: .black))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("LBS")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppColors.textPrimary.opacity(0.6))
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Stats Grid
                VStack(alignment: .leading, spacing: 16) {
                    statRow(label: "DISTANCE", value: formattedDistance)
                    statRow(label: "TIME", value: formattedTime)
                    statRow(label: "PACE", value: formattedPace)
                    if payload.showElevation && payload.elevationGain > 0 {
                        statRow(label: "ELEVATION", value: formattedElevation)
                    }
                    if payload.showCalories {
                        statRow(label: "CALORIES", value: "\(payload.calories) kcal")
                    }
                }
                
                Spacer()
                
                // Footer section
                VStack(alignment: .leading, spacing: 12) {
                    // Club Badge (if training with a club)
                    if let clubName = payload.clubName, !clubName.isEmpty {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(AppColors.primary)
                                .frame(width: 4)
                            
                            Text("TRAINING WITH ")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.textPrimary.opacity(0.7))
                            + Text(clubName.uppercased())
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(AppColors.primary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.primary.opacity(0.1))
                        )
                    }
                    
                    // Share URL
                    if let shareURL = payload.shareURL {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("JOIN THE RUCK")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppColors.textPrimary.opacity(0.6))
                                .tracking(1)
                            Text(shareURL.absoluteString)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
            .padding(40)
        }
        .frame(width: format.size.width, height: format.size.height)
    }
    
    private func statRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textPrimary.opacity(0.6))
                .tracking(2)
            Text(value)
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

