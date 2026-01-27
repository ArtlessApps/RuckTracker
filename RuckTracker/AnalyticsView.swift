//
//  AnalyticsView.swift
//  MARCH
//
//  Comprehensive analytics view combining advanced analytics with workout history
//

import SwiftUI
import CoreData

struct AnalyticsView: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var premiumManager: PremiumManager
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var showAllWorkouts: Bool
    
    @State private var showingDeleteAlert = false
    @State private var workoutToDelete: WorkoutEntity?
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        if workoutDataManager.workouts.isEmpty {
                            emptyStateView
                        } else {
                            analyticsContentView
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .alert("Delete Workout", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let workout = workoutToDelete {
                        workoutDataManager.deleteWorkout(workout)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this workout? This action cannot be undone.")
            }
            .sheet(isPresented: $premiumManager.showingPaywall) {
                SubscriptionPaywallView(context: premiumManager.paywallContext)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textSecondary)
            
            Text("No Activity Data Yet")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Start your first rucking workout to see detailed analytics, progress charts, and performance insights here.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Analytics Content
    
    private var analyticsContentView: some View {
        VStack(spacing: 20) {
            // Advanced Analytics Section
            if workoutDataManager.totalWorkouts >= 3 {
                advancedAnalyticsSection
            }
            
            // Summary Stats Card
            summaryStatsCard
        }
    }
    
    // MARK: - Advanced Analytics Section
    
    private var advancedAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Advanced Analytics")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundColor(AppColors.textOnLight)
                
                Spacer()
                
            }
            
            // Use existing WeeklyProgressChart and PerformanceInsightsCard
            if premiumManager.isPremiumUser {
                VStack(spacing: 16) {
                    WeeklyProgressChart()
                    PerformanceInsightsCard()
                }
            } else {
                lockedAnalyticsView
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadowBlackSubtle, radius: 8, x: 0, y: 2)
        )
    }
    
    private var lockedAnalyticsView: some View {
        WeeklyProgressChart()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.shadowBlack)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundColor(AppColors.primary)
                            
                            Text("Premium Analytics")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Detailed charts and insights")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
            )
    }
    
    // MARK: - Summary Stats Card
    
    private var summaryStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundColor(AppColors.textOnLight)
            
            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                SummaryStatBox(
                    value: "\(workoutDataManager.totalWorkouts)",
                    label: "Workouts",
                    color: AppColors.primary
                )
                
                SummaryStatBox(
                    value: String(format: "%.1f", totalDistance),
                    label: "mi",
                    color: AppColors.primary
                )
                
                SummaryStatBox(
                    value: "\(totalCalories)",
                    label: "Calories",
                    color: AppColors.accentGreen
                )
                
                SummaryStatBox(
                    value: formattedTotalTime,
                    label: "Total Time",
                    color: AppColors.accentTeal
                )
            }
            
            // Avg Pace - centered below
            SummaryStatBox(
                value: formattedAvgPace,
                label: "Avg Pace",
                color: .orange,
                fullWidth: true
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.shadowBlackSubtle, radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Computed Properties
    
    private var totalDistance: Double {
        workoutDataManager.workouts.reduce(0) { $0 + $1.distance }
    }
    
    private var totalCalories: Int {
        Int(workoutDataManager.workouts.reduce(0) { $0 + $1.calories })
    }
    
    private var formattedTotalTime: String {
        let totalSeconds = workoutDataManager.workouts.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    private var formattedAvgPace: String {
        let totalDistance = workoutDataManager.workouts.reduce(0) { $0 + $1.distance }
        let totalTime = workoutDataManager.workouts.reduce(0) { $0 + $1.duration }
        
        guard totalDistance > 0 else { return "--" }
        
        let avgPaceSeconds = totalTime / totalDistance
        let minutes = Int(avgPaceSeconds) / 60
        let seconds = Int(avgPaceSeconds) % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Summary Stat Box Component (New)

struct SummaryStatBox: View {
    let value: String
    let label: String
    let color: Color
    var fullWidth: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: fullWidth ? 32 : 28, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, fullWidth ? 16 : 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - MetricView Component (Used by other views)

struct MetricView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(minWidth: 140, maxWidth: .infinity)
    }
}

// Re-use existing PremiumBadge, WeeklyProgressChart, PerformanceInsightsCard from PremiumIntegration.swift

#Preview {
    AnalyticsView(showAllWorkouts: .constant(false))
        .environmentObject(WorkoutDataManager.shared)
        .environmentObject(PremiumManager.shared)
}
