//
//  HeartRateZoneCalculator.swift
//  RuckTracker
//
//  Maps BPM to heart rate zones. Thresholds match the Watch app (v1).
//  Age-based max HR personalization is a future enhancement.
//

import Foundation
import SwiftUI

enum HeartRateZoneCalculator {
    /// Zone thresholds aligned with Watch WorkoutManager.
    static func zone(for heartRate: Double) -> HeartRateZone? {
        guard heartRate > 0 else { return nil }
        switch heartRate {
        case 0..<100: return .recovery
        case 100..<130: return .aerobic
        case 130..<150: return .threshold
        case 150..<170: return .anaerobic
        default: return .neuromuscular
        }
    }
    
    static func zoneNumber(for zone: HeartRateZone) -> Int {
        switch zone {
        case .recovery: return 1
        case .aerobic: return 2
        case .threshold: return 3
        case .anaerobic: return 4
        case .neuromuscular: return 5
        }
    }
    
    static func displayLabel(for zone: HeartRateZone) -> String {
        "\(zone.rawValue) · Z\(zoneNumber(for: zone))"
    }
    
    static func color(for zone: HeartRateZone) -> Color {
        switch zone {
        case .recovery: return Color.blue
        case .aerobic: return Color.green
        case .threshold: return Color.yellow
        case .anaerobic: return Color.orange
        case .neuromuscular: return Color.red
        }
    }
    
    static func formattedDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return totalMinutes > 0 ? "\(totalMinutes)m" : "<1m"
    }
}
