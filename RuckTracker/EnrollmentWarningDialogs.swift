//
//  EnrollmentWarningDialogs.swift
//  RuckTracker
//
//  Reusable warning dialogs for enrollment conflicts and leaving
//

import SwiftUI

// MARK: - Leave Warning Dialog

struct LeaveWarningDialog: View {
    let type: EnrollmentType // .challenge or .program
    let name: String
    let completedCount: Int
    let totalCount: Int
    let workoutCount: Int
    let onLeave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(Color("PrimaryMain"))
            
            // Title
            Text("Leave \(name)?")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Progress stats
            VStack(alignment: .leading, spacing: 8) {
                if type == .challenge {
                    Text("You've completed \(completedCount) of \(totalCount) days")
                } else {
                    Text("You've completed \(completedCount) of \(totalCount) weeks")
                }
                
                Text("Progress: \(progressPercentage)% complete")
                
                if workoutCount > 0 {
                    Text("\(workoutCount) \(workoutCount == 1 ? "workout" : "workouts") will be deleted")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            // Warning text
            Text("Leaving will permanently delete all progress and workout data.")
                .font(.callout)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: onLeave) {
                    Text("Leave")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
            }
        }
        .padding(24)
    }
    
    private var progressPercentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(completedCount) / Double(totalCount)) * 100)
    }
}

// MARK: - Enrollment Conflict Dialog

struct EnrollmentConflictDialog: View {
    let type: EnrollmentType
    let currentName: String
    let newName: String
    let completedCount: Int
    let totalCount: Int
    let workoutCount: Int
    let onSwitch: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 50))
                .foregroundColor(Color("PrimaryMain"))
            
            // Title
            Text("Already Enrolled")
                .font(.title2)
                .fontWeight(.bold)
            
            // Current enrollment info
            VStack(alignment: .leading, spacing: 4) {
                Text("You're currently enrolled in:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(currentName)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Progress stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Progress:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if type == .challenge {
                    Text("• \(completedCount) of \(totalCount) days complete (\(progressPercentage)%)")
                } else {
                    Text("• \(completedCount) of \(totalCount) weeks complete (\(progressPercentage)%)")
                }
                
                if workoutCount > 0 {
                    Text("• \(workoutCount) \(workoutCount == 1 ? "workout" : "workouts") recorded")
                }
            }
            .font(.subheadline)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            // Warning text
            Text("Enrolling in \(newName) will permanently delete your current progress and all workout data.")
                .font(.callout)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: onSwitch) {
                    Text("Switch to \(newName)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
            }
        }
        .padding(24)
    }
    
    private var progressPercentage: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(completedCount) / Double(totalCount)) * 100)
    }
}

// MARK: - Supporting Types

enum EnrollmentType {
    case challenge
    case program
}
