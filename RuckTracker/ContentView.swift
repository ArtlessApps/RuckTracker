import SwiftUI

struct ContentView: View {
    var body: some View {
        PhoneMainView()
            .environmentObject(WorkoutDataManager.shared)
            .environmentObject(WorkoutManager())
            .environmentObject(PremiumManager.shared)
    }
}

#Preview {
    ContentView()
}
