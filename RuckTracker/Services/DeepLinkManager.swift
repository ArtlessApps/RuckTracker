import Foundation
import Combine

/// Centralized deep link handling for universal links and short links.
final class DeepLinkManager: ObservableObject {
    enum Destination: Equatable {
        case workoutShare(code: String)
        case workoutHistory
    }
    
    /// Latest destination emitted from a deep link.
    @Published var pendingDestination: Destination?
    
    /// Attempt to handle any incoming URL (universal link or custom scheme).
    func handle(url: URL) {
        // Example supported paths:
        // https://rucktracker.app/s/<code>
        // https://rucktracker.app/w/<workoutObjectUri>
        DebugLogger.shared.log("🔗 Deep link received: \(url.absoluteString)")
        let components = url.pathComponents.filter { $0 != "/" }
        
        guard let first = components.first else {
            pendingDestination = .workoutHistory
            return
        }
        
        switch first.lowercased() {
        case "s", "share", "w":
            if components.count >= 2 {
                pendingDestination = .workoutShare(code: components[1])
            } else {
                pendingDestination = .workoutHistory
            }
        default:
            pendingDestination = .workoutHistory
        }
    }
}

