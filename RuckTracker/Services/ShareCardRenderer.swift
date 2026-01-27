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
            LinearGradient(
                colors: [AppColors.background, AppColors.primary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(payload.title.uppercased())
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(formattedDate)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.75))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("MARCH")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                
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
                    if payload.showWeight {
                        statRow(label: "WEIGHT", value: "\(payload.ruckWeight) lbs")
                    }
                }
                
                Spacer()
                
                if let shareURL = payload.shareURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JOIN THE RUCK")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary.opacity(0.7))
                        Text(shareURL.absoluteString)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textPrimary.opacity(0.7))
                .tracking(1)
            Text(value)
                .font(.system(size: 36, weight: .heavy))
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

