import SwiftUI
import Foundation

// MARK: - Premium Status Banner
struct PremiumStatusBanner: View {
    @EnvironmentObject var premiumManager: PremiumManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Premium Active")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Unlock all features and advanced analytics")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Free Trial Banner
struct FreeTrialBanner: View {
    @EnvironmentObject var premiumManager: PremiumManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Try Premium Free")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("7-day free trial, then $4.99/month")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Button(action: {
                    premiumManager.showPaywall(context: .featureUpsell)
                }) {
                    Text("Start Trial")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .buttonStyle(.plain)
    }
}

// MARK: - Premium Data Section
struct PremiumDataSection: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @State private var exportMessage = ""
    @State private var showingAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Export Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                PremiumBadge(size: .small)
            }
            
            PremiumFeatureCard(
                icon: "square.and.arrow.up",
                title: "Export Data",
                description: "Export your workout data to CSV",
                isLocked: false
            ) {
                exportToCSV()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
        .alert("Export Result", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(exportMessage)
        }
    }
    
    private func exportToCSV() {
        let csvData = generateCSVData()
        shareData(csvData, fileName: "RuckTracker_Workouts.csv", mimeType: "text/csv")
    }
    
    
    private func generateCSVData() -> Data {
        var csvString = "Date,Duration (minutes),Distance (miles),Calories,Ruck Weight (lbs),Heart Rate (bpm)\n"
        
        for workout in workoutDataManager.workouts {
            let dateString = workout.date?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown"
            let durationMinutes = workout.duration / 60
            csvString += "\(dateString),\(String(format: "%.2f", durationMinutes)),\(String(format: "%.2f", workout.distance)),\(Int(workout.calories)),\(Int(workout.ruckWeight)),\(Int(workout.heartRate))\n"
        }
        
        return csvString.data(using: .utf8) ?? Data()
    }
    
    
    private func shareData(_ data: Data, fileName: String, mimeType: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            
            DispatchQueue.main.async {
                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    
                    // Handle iPad presentation
                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceView = window
                        popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    
                    rootVC.present(activityVC, animated: true)
                }
            }
        } catch {
            exportMessage = "Failed to export data: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
}

// MARK: - Premium Feature Card
struct PremiumFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isLocked ? .gray : .blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isLocked {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isLocked ? Color.gray.opacity(0.1) : Color.blue.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

// Note: PremiumAnalyticsSection, AnalyticsEmptyState, WeeklyProgressChart, 
// PerformanceInsightsCard, and InsightRow are already defined in PremiumIntegration.swift
