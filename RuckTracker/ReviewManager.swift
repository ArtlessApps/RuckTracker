
// ReviewManager.swift
// Manages App Store review prompts at key milestones in the rucking journey.

import StoreKit
import UIKit

final class ReviewManager {
    static let shared = ReviewManager()
    private init() {}

    // MARK: - UserDefaults Keys
    private let kLastReviewAtWorkoutCount = "reviewManager_lastRequestedAtCount"
    private let kTotalReviewRequests = "reviewManager_totalRequests"

    // Thresholds: ask after completing these ruck counts.
    // Apple silently caps actual prompts at 3 per 365-day rolling window.
    private let reviewThresholds: Set<Int> = [1, 5, 20]

    // MARK: - Public API

    /// Call this after each workout is saved. Pass the new total workout count.
    func considerRequestingReview(totalWorkouts: Int) {
        guard reviewThresholds.contains(totalWorkouts) else { return }

        let lastRequestedAt = UserDefaults.standard.integer(forKey: kLastReviewAtWorkoutCount)
        guard lastRequestedAt != totalWorkouts else { return } // already asked at this count

        UserDefaults.standard.set(totalWorkouts, forKey: kLastReviewAtWorkoutCount)
        UserDefaults.standard.set(
            UserDefaults.standard.integer(forKey: kTotalReviewRequests) + 1,
            forKey: kTotalReviewRequests
        )

        requestReview()
    }

    // MARK: - Private

    private func requestReview() {
        DispatchQueue.main.async {
            guard
                let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
