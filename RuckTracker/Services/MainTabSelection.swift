import SwiftUI
import Combine

/// Shared tab selection state that can be controlled from any view in the hierarchy.
/// Inject as `@EnvironmentObject var tabSelection: MainTabSelection`.
final class MainTabSelection: ObservableObject {
    
    // MARK: - Tab Enum
    
    enum Tab: Int, CaseIterable {
        case ruck     = 0
        case coach    = 1   // "Plan" tab
        case tribe    = 2
        case rankings = 3
        case you      = 4
    }
    
    // MARK: - Published State
    
    @Published var selectedTab: Tab = .ruck
}
