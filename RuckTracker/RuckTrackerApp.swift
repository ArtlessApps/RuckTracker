import SwiftUI

@main
struct RuckTrackerApp: App {
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var workoutDataManager = WorkoutDataManager.shared
    @StateObject private var watchConnectivityManager = WatchConnectivityManager.shared
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    // Add these for premium functionality
    @StateObject private var storeKitManager = StoreKitManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
                .environmentObject(workoutManager)
                .environmentObject(workoutDataManager)
                .environmentObject(supabaseManager)
                .environmentObject(storeKitManager)    // Add this
                .environmentObject(premiumManager)     // Add this
                .onAppear {
                    // Set up WatchConnectivity manager
                    watchConnectivityManager.setWorkoutDataManager(workoutDataManager)
                    
                    // Request HealthKit authorization
                    healthManager.requestAuthorization()
                    
                    // Initialize StoreKit and Premium Manager
                    Task {
                        await storeKitManager.loadProducts()
                        print("🛒 StoreKit products loaded")
                    }
                    
                    // Request workouts from watch if available
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        watchConnectivityManager.requestWorkoutsFromWatch()
                    }
                }
        }
    }
}
