
// ReviewManager.swift
// Sentiment gate before App Store reviews; routes unhappy users to in-app feedback.

import StoreKit
import SwiftUI

enum FeedbackSource: String {
    case postWorkout = "post_workout"
    case sentimentGate = "sentiment_gate"
    case settings = "settings"
}

@MainActor
final class ReviewManager: ObservableObject {
    static let shared = ReviewManager()

    @Published var showingSentimentGate = false
    @Published var showingFeedbackForm = false
    @Published var feedbackSource: FeedbackSource = .settings

    // MARK: - UserDefaults Keys

    private let kLastReviewAtWorkoutCount = "reviewManager_lastRequestedAtCount"
    private let kLastNegativeResponseDate = "reviewManager_lastNegativeResponseDate"
    private let kTotalReviewRequests = "reviewManager_totalRequests"

    // Thresholds: ask after completing these ruck counts.
    // Apple silently caps actual prompts at 3 per 365-day rolling window.
    private let reviewThresholds: Set<Int> = [1, 5, 20]
    private let negativeCooldownDays = 90

    private init() {}

    // MARK: - Public API

    /// Call after each workout is saved. Pass the new total workout count.
    func considerRequestingReview(totalWorkouts: Int) {
        guard reviewThresholds.contains(totalWorkouts) else { return }

        let lastRequestedAt = UserDefaults.standard.integer(forKey: kLastReviewAtWorkoutCount)
        guard lastRequestedAt != totalWorkouts else { return }
        guard !isInNegativeCooldown() else { return }

        UserDefaults.standard.set(totalWorkouts, forKey: kLastReviewAtWorkoutCount)
        feedbackSource = .postWorkout
        showingSentimentGate = true
    }

    func userEnjoyingApp() {
        showingSentimentGate = false
        UserDefaults.standard.set(
            UserDefaults.standard.integer(forKey: kTotalReviewRequests) + 1,
            forKey: kTotalReviewRequests
        )
        requestReview()
    }

    func userNotEnjoyingApp() {
        showingSentimentGate = false
        UserDefaults.standard.set(Date(), forKey: kLastNegativeResponseDate)
        feedbackSource = .sentimentGate
        // Brief delay so the sentiment sheet can dismiss before presenting feedback.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.showingFeedbackForm = true
        }
    }

    // MARK: - Private

    private func isInNegativeCooldown() -> Bool {
        guard let declined = UserDefaults.standard.object(forKey: kLastNegativeResponseDate) as? Date else {
            return false
        }
        let days = Calendar.current.dateComponents([.day], from: declined, to: Date()).day ?? 0
        return days < negativeCooldownDays
    }

    private func requestReview() {
        guard
            let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}
