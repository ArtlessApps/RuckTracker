import SwiftUI
import Foundation

// MARK: - Premium Status Banner
struct PremiumStatusBanner: View {
    @StateObject private var premiumManager = PremiumManager.shared
    
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
                        colors: [Color.yellow.opacity(0.1), Color("PrimaryMain").opacity(0.1)],
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
    @StateObject private var premiumManager = PremiumManager.shared
    
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
                        .background(AppColors.cardBackground)
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
    @State private var isExporting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Export Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            PremiumFeatureCard(
                icon: isExporting ? "arrow.clockwise" : "square.and.arrow.up",
                title: isExporting ? "Exporting..." : "Export Data",
                description: isExporting ? "Preparing your workout data..." : "Export your workout data to CSV",
                isLocked: false
            ) {
                if !isExporting {
                    exportToCSV()
                }
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
        // Check if there are workouts to export
        guard !workoutDataManager.workouts.isEmpty else {
            exportMessage = "No workout data to export. Complete some workouts first!"
            showingAlert = true
            return
        }
        
        isExporting = true
        
        // Generate CSV data on background queue for better performance
        DispatchQueue.global(qos: .userInitiated).async {
            let csvData = self.generateCSVData()
            
            DispatchQueue.main.async {
                self.shareData(csvData, fileName: "MARCH_Workouts.csv", mimeType: "text/csv")
            }
        }
    }
    
    
    private func generateCSVData() -> Data {
        // Create a more comprehensive CSV header
        var csvString = "Date,Time,Duration (minutes),Distance (miles),Calories,Ruck Weight (lbs),Heart Rate (bpm),Notes\n"
        
        // Sort workouts by date (most recent first)
        let sortedWorkouts = workoutDataManager.workouts.sorted { workout1, workout2 in
            guard let date1 = workout1.date, let date2 = workout2.date else { return false }
            return date1 > date2
        }
        
        for workout in sortedWorkouts {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            let dateString = workout.date?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown"
            let timeString = workout.date?.formatted(date: .omitted, time: .shortened) ?? "Unknown"
            let durationMinutes = workout.duration / 60
            
            // No notes field available in WorkoutEntity, using empty string
            let notes = ""
            
            csvString += "\(dateString),\(timeString),\(String(format: "%.2f", durationMinutes)),\(String(format: "%.2f", workout.distance)),\(Int(workout.calories)),\(Int(workout.ruckWeight)),\(Int(workout.heartRate)),\(notes)\n"
        }
        
        return csvString.data(using: .utf8) ?? Data()
    }
    
    
    private func shareData(_ data: Data, fileName: String, mimeType: String) {
        // Use Documents directory instead of temporary directory for better file access
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            // Write the data
            try data.write(to: fileURL)
            
            // Add a small delay to ensure any current presentations are dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.presentActivityViewController(with: fileURL)
            }
        } catch {
            exportMessage = "Failed to export data: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func presentActivityViewController(with url: URL) {
        // Create a more robust file sharing approach
        let activityItems: [Any] = [url]
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // Exclude some activity types that might cause issues
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        
        // Set a completion handler to ensure proper cleanup
        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            DispatchQueue.main.async {
                self.isExporting = false
                
                if let error = error {
                    self.exportMessage = "Export failed: \(error.localizedDescription)"
                    self.showingAlert = true
                } else if completed {
                    self.exportMessage = "Export completed successfully! Your workout data has been shared."
                    self.showingAlert = true
                }
                
                // Clean up the file after a delay
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        
        // Find the topmost presented view controller to avoid presentation conflicts
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            exportMessage = "Unable to present export options. Please try again."
            showingAlert = true
            return
        }
        
        // Find the topmost presented view controller
        var topVC = rootVC
        while let presentedVC = topVC.presentedViewController {
            topVC = presentedVC
        }
        
        // Handle iPad presentation
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Present from the topmost view controller
        topVC.present(activityVC, animated: true)
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
                                .foregroundColor(Color("PrimaryMain"))
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

// Note: PremiumAnalyticsSection, AnalyticsEmptyState, WeeklyProgressChart are already defined in PremiumIntegration.swift
