//
//  HealthImportViews.swift
//  MARCH
//
//  UI for rucks imported from other watches via Apple Health:
//  review sheet, home banner, and settings section.
//

import SwiftUI

// MARK: - Review Sheet

struct HealthImportReviewView: View {
    @ObservedObject private var importService = HealthImportService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()

                if importService.pending.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(AppColors.primary)
                        Text("All caught up")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Walks and hikes from Garmin, COROS, and other watches will show up here after they sync to Apple Health.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            Text("These workouts were recorded on another watch. Log the ones where you carried a pack.")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(importService.pending) { candidate in
                                ImportCandidateCard(candidate: candidate)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Rucks From Your Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ImportCandidateCard: View {
    let candidate: ImportCandidate
    @State private var weightLbs: Double

    init(candidate: ImportCandidate) {
        self.candidate = candidate
        _weightLbs = State(initialValue: HealthImportService.shared.lastWeightLbs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "applewatch")
                    .foregroundColor(AppColors.primary)
                Text("\(candidate.activityName) · \(candidate.sourceName)")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(candidate.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            HStack(spacing: 0) {
                stat(HealthImportService.formatDistance(candidate.distanceMiles), "Distance")
                stat(HealthImportService.formatDuration(candidate.duration), "Time")
                if candidate.averageHeartRate > 0 {
                    stat("\(Int(candidate.averageHeartRate)) bpm", "Avg HR")
                }
            }

            Divider()
                .background(AppColors.textSecondary.opacity(0.3))

            Stepper(value: $weightLbs, in: 0...150, step: 5) {
                HStack {
                    Text("Pack Weight")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text("\(Int(weightLbs)) lbs")
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            HStack(spacing: 12) {
                Button {
                    HealthImportService.shared.dismiss(candidate)
                } label: {
                    Text("Not a Ruck")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.surfaceAlt)
                        .foregroundColor(AppColors.textSecondary)
                        .cornerRadius(10)
                }

                Button {
                    HealthImportService.shared.log(candidate, weightLbs: weightLbs)
                } label: {
                    Text("Log Ruck")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.primary)
                        .foregroundColor(AppColors.textOnLight)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
        )
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Home Banner

/// Shown on the home screen while imported workouts are waiting for review
struct HealthImportBanner: View {
    @ObservedObject private var importService = HealthImportService.shared

    var body: some View {
        if !importService.pending.isEmpty {
            Button {
                importService.showingReview = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.primary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(importService.pending.count == 1
                             ? "1 workout from your watch"
                             : "\(importService.pending.count) workouts from your watch")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Tap to log your rucks")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.surface)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Settings Section

struct HealthImportSettingsSection: View {
    @ObservedObject private var importService = HealthImportService.shared
    // Settings is itself a sheet, so present the review from here
    @State private var showingReview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Other Watches")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)

                Text("Import rucks from Garmin, COROS, Polar, Suunto, and other watches that sync to Apple Health. Record your ruck as a walk or hike on the watch.")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            VStack(spacing: 12) {
                Toggle("Import From Apple Health", isOn: $importService.isEnabled)
                    .foregroundColor(AppColors.textPrimary)
                    .tint(AppColors.primary)

                if importService.isEnabled {
                    Divider()
                        .background(AppColors.textSecondary.opacity(0.3))

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Log Automatically", isOn: $importService.autoLog)
                            .foregroundColor(AppColors.textPrimary)
                            .tint(AppColors.primary)
                        Text("Log new walks and hikes at \(Int(importService.lastWeightLbs)) lbs without asking")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Divider()
                        .background(AppColors.textSecondary.opacity(0.3))

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Include Apple Workout App", isOn: $importService.includeAppleWorkouts)
                            .foregroundColor(AppColors.textPrimary)
                            .tint(AppColors.primary)
                        Text("Also check walks and hikes recorded with Apple's Workout app")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    if !importService.pending.isEmpty {
                        Divider()
                            .background(AppColors.textSecondary.opacity(0.3))

                        Button {
                            showingReview = true
                        } label: {
                            HStack {
                                Text("Review \(importService.pending.count) Workout\(importService.pending.count == 1 ? "" : "s")")
                                    .foregroundColor(AppColors.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
            )
        }
        .sheet(isPresented: $showingReview) {
            HealthImportReviewView()
        }
    }
}
