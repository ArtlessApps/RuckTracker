//
//  AnalyticsView.swift
//  RuckTracker
//
//  Comprehensive analytics view combining advanced analytics with workout history
//

import SwiftUI
import CoreData

struct AnalyticsView: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var premiumManager: PremiumManager
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.presentationMode) var presentationMode
    @Binding var showAllWorkouts: Bool
    
    @State private var showingDeleteAlert = false
    @State private var workoutToDelete: WorkoutEntity?
    
    var body: some View {
        NavigationView {
            ScrollView {
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
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color("PrimaryMain"))
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
                .foregroundColor(Color("PrimaryMain").opacity(0.6))
            
            Text("No Activity Data Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start your first rucking workout to see detailed analytics, progress charts, and performance insights here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Analytics Content
    
    private var analyticsContentView: some View {
        VStack(spacing: 24) {
            // Advanced Analytics Section
            if workoutDataManager.totalWorkouts >= 3 {
                advancedAnalyticsSection
            }
            
            // Quick Stats Dashboard
            quickStatsSection
            
            // Workout History Section
            workoutHistorySection
        }
    }
    
    // MARK: - Advanced Analytics Section
    
    private var advancedAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Advanced Analytics")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !premiumManager.isPremiumUser {
                    Button(action: {
                        premiumManager.showPaywall(context: .featureUpsell)
                    }) {
                        PremiumBadge(size: .small)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if premiumManager.isPremiumUser {
                VStack(spacing: 16) {
                    WeeklyProgressChart()
                    PerformanceInsightsCard()
                }
            } else {
                lockedAnalyticsView
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    private var lockedAnalyticsView: some View {
        WeeklyProgressChart()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundColor(Color("PrimaryMain"))
                            
                            Text("Premium Analytics")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("Detailed charts and insights")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
            )
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.title2)
                .fontWeight(.semibold)
            
            WorkoutStatsCardView()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    // MARK: - Workout History Section
    
    private var workoutHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Workouts")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("(\(workoutDataManager.totalWorkouts))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(workoutDataManager.workouts.prefix(10), id: \.objectID) { workout in
                    WorkoutDetailCardView(workout: workout) {
                        workoutToDelete = workout
                        showingDeleteAlert = true
                    }
                }
                
                if workoutDataManager.totalWorkouts > 10 {
                    Button(action: {
                        showAllWorkouts = true
                    }) {
                        HStack {
                            Text("View All Workouts")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(Color("PrimaryMain"))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("PrimaryMain").opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Supporting Views

struct WorkoutStatsCardView: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @ObservedObject private var userSettings = UserSettings.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                StatItemView(
                    value: "\(workoutDataManager.totalWorkouts)",
                    label: "Workouts",
                    color: Color("PrimaryMain")
                )
                
                StatItemView(
                    value: {
                        let displayDistance = userSettings.preferredDistanceUnit == .miles ? 
                            workoutDataManager.totalDistance : 
                            workoutDataManager.totalDistance / userSettings.preferredDistanceUnit.conversionToMiles
                        return String(format: "%.1f", displayDistance)
                    }(),
                    label: userSettings.preferredDistanceUnit.rawValue,
                    color: .blue
                )
                
                StatItemView(
                    value: "\(Int(workoutDataManager.totalCalories))",
                    label: "Calories",
                    color: .green
                )
            }
            
            HStack(spacing: 20) {
                StatItemView(
                    value: {
                        let hours = Int(workoutDataManager.totalDuration / 3600)
                        let minutes = Int(workoutDataManager.totalDuration.truncatingRemainder(dividingBy: 3600) / 60)
                        return "\(hours)h \(minutes)m"
                    }(),
                    label: "Total Time",
                    color: .purple
                )
                
                if let avgPace = workoutDataManager.averagePace {
                    StatItemView(
                        value: {
                            let minutes = Int(avgPace)
                            let seconds = Int((avgPace - Double(minutes)) * 60)
                            return String(format: "%d:%02d", minutes, seconds)
                        }(),
                        label: "Avg Pace",
                        color: .red
                    )
                } else {
                    StatItemView(
                        value: "--",
                        label: "Avg Pace",
                        color: .red
                    )
                }
                
                Spacer()
            }
        }
    }
}

struct StatItemView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutDetailCardView: View {
    let workout: WorkoutEntity
    let onDelete: () -> Void
    @ObservedObject private var userSettings = UserSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with date and weight
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.formattedDate)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(Int(workout.ruckWeight)) lbs")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("PrimaryMain"))
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            // Main metrics
            HStack(spacing: 16) {
                MetricView(
                    value: workout.formattedDuration,
                    label: "Duration",
                    color: .blue
                )
                
                MetricView(
                    value: workout.formattedDistance(unit: userSettings.preferredDistanceUnit),
                    label: "Distance",
                    color: .green
                )
                
                MetricView(
                    value: "\(Int(workout.calories))",
                    label: "Calories",
                    color: Color("PrimaryMain")
                )
                
                MetricView(
                    value: workout.formattedPace,
                    label: "Pace",
                    color: Color(workout.paceColor)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

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
                .foregroundColor(.secondary)
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
