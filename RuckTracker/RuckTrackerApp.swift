import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // HealthKit background delivery requires the observer query to be set up at launch
        HealthImportService.shared.start()
        return true
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        _ = await HealthImportService.shared.handleNotificationResponse(response)
    }
}

@main
struct RuckTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var healthManager = HealthManager.shared
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var workoutDataManager = WorkoutDataManager.shared
    @StateObject private var watchConnectivityManager = WatchConnectivityManager.shared
    @StateObject private var deepLinkManager = DeepLinkManager()
    
    // Add these for premium functionality
    @StateObject private var storeKitManager = StoreKitManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
                .environmentObject(workoutManager)
                .environmentObject(workoutDataManager)
                .environmentObject(storeKitManager)    // Add this
                .environmentObject(premiumManager)     // Add this
                .environmentObject(deepLinkManager)
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
                    
                    // Eagerly restore any persisted Supabase session so the
                    // user doesn't have to log in again after a cold launch.
                    // CommunityService.init already fires restoreSessionIfNeeded(),
                    // but accessing .shared here ensures it runs early.
                    print("🔑 [AUTH][App] onAppear — initializing CommunityService.shared")
                    _ = CommunityService.shared
                    print("🔑 [AUTH][App] onAppear — CommunityService.shared initialized, isAuthenticated=\(CommunityService.shared.isAuthenticated)")
                    
                    // Request workouts from watch if available
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        watchConnectivityManager.requestWorkoutsFromWatch()
                    }
                }
                .onOpenURL { url in
                    deepLinkManager.handle(url: url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        deepLinkManager.handle(url: url)
                    }
                }
        }
    }
}
