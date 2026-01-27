//
//  WatchConnectivityManager.swift
//  RuckTracker
//
//  Manages communication between iPhone and Apple Watch apps
//

import Foundation
import WatchConnectivity
import CoreData
import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isWatchAppInstalled = false
    @Published var isWatchReachable = false
    @Published var lastSyncDate: Date?
    
    private var workoutDataManager: WorkoutDataManager?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func setWorkoutDataManager(_ manager: WorkoutDataManager) {
        self.workoutDataManager = manager
    }
    
    // MARK: - Public Methods
    
    /// Request all workouts from the watch
    func requestWorkoutsFromWatch() {
        guard isWatchReachable else {
            print("📱 Watch not reachable, cannot request workouts")
            return
        }
        
        let message = [WatchConnectivityKeys.requestWorkouts: true]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ Failed to request workouts from watch: \(error.localizedDescription)")
        }
        
        print("📱 Requested workouts from watch")
    }
    
    /// Send a single workout to the watch (for backup/sync)
    func sendWorkoutToWatch(_ workout: WorkoutEntity) {
        guard isWatchReachable else {
            print("📱 Watch not reachable, cannot send workout")
            return
        }
        
        let transferData = WorkoutTransferData(from: workout)
        
        do {
            let data = try JSONEncoder().encode(transferData)
            let message = [WatchConnectivityKeys.workoutData: data]
            
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("❌ Failed to send workout to watch: \(error.localizedDescription)")
            }
            
            print("📱 Sent workout to watch: \(workout.date?.formatted() ?? "unknown date")")
        } catch {
            print("❌ Failed to encode workout data: \(error.localizedDescription)")
        }
    }
    
    /// Send a command to start a workout on the watch
    func sendStartWorkoutCommand() {
        guard isWatchReachable else {
            print("📱 Watch not reachable, cannot start workout")
            return
        }
        
        let message = [WatchConnectivityKeys.startWorkout: true]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ Failed to send start workout command to watch: \(error.localizedDescription)")
        }
        
        print("📱 Sent start workout command to watch")
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:
                print("📱 WatchConnectivity activated")
                self.isWatchAppInstalled = session.isWatchAppInstalled
                self.isWatchReachable = session.isReachable
            case .inactive:
                print("📱 WatchConnectivity inactive")
                self.isWatchAppInstalled = false
                self.isWatchReachable = false
            case .notActivated:
                print("📱 WatchConnectivity not activated")
                self.isWatchAppInstalled = false
                self.isWatchReachable = false
            @unknown default:
                print("📱 WatchConnectivity unknown state")
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = false
            print("📱 Watch became inactive")
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = false
            print("📱 Watch deactivated")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("📱 Watch reachability changed: \(session.isReachable)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
            replyHandler(["status": "received"])
        }
    }
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        // Handle workout data from watch
        if let workoutData = message[WatchConnectivityKeys.workoutData] as? Data {
            handleReceivedWorkoutData(workoutData)
        }
        
        // Handle multiple workouts from watch
        if let allWorkoutsData = message[WatchConnectivityKeys.sendAllWorkouts] as? Data {
            handleReceivedAllWorkouts(allWorkoutsData)
        }
        
        // Handle workout request from watch
        if let _ = message[WatchConnectivityKeys.requestWorkouts] as? Bool {
            handleWorkoutRequest()
        }
    }
    
    private func handleReceivedWorkoutData(_ data: Data) {
        do {
            let transferData = try JSONDecoder().decode(WorkoutTransferData.self, from: data)
            
            guard let workoutDataManager = workoutDataManager else {
                print("❌ No WorkoutDataManager available to save workout")
                return
            }
            
            // Check if workout already exists (by date and duration)
            let existingWorkouts = workoutDataManager.workouts.filter { workout in
                guard let workoutDate = workout.date else { return false }
                return abs(workoutDate.timeIntervalSince(transferData.date)) < 60 && // Within 1 minute
                       abs(workout.duration - transferData.duration) < 10 // Within 10 seconds
            }
            
            if existingWorkouts.isEmpty {
                // Save new workout
                workoutDataManager.saveWorkout(
                    date: transferData.date,
                    duration: transferData.duration,
                    distance: transferData.distance,
                    calories: transferData.calories,
                    ruckWeight: transferData.ruckWeight,
                    heartRate: transferData.heartRate
                )
                
                print("📱 Received and saved workout from watch: \(transferData.date.formatted())")
                lastSyncDate = Date()
            } else {
                print("📱 Workout already exists, skipping duplicate")
            }
            
        } catch {
            print("❌ Failed to decode workout data from watch: \(error.localizedDescription)")
        }
    }
    
    private func handleReceivedAllWorkouts(_ data: Data) {
        do {
            let allWorkouts = try JSONDecoder().decode([WorkoutTransferData].self, from: data)
            
            guard let workoutDataManager = workoutDataManager else {
                print("❌ No WorkoutDataManager available to save workouts")
                return
            }
            
            var savedCount = 0
            for transferData in allWorkouts {
                // Check if workout already exists
                let existingWorkouts = workoutDataManager.workouts.filter { workout in
                    guard let workoutDate = workout.date else { return false }
                    return abs(workoutDate.timeIntervalSince(transferData.date)) < 60 &&
                           abs(workout.duration - transferData.duration) < 10
                }
                
                if existingWorkouts.isEmpty {
                    workoutDataManager.saveWorkout(
                        date: transferData.date,
                        duration: transferData.duration,
                        distance: transferData.distance,
                        calories: transferData.calories,
                        ruckWeight: transferData.ruckWeight,
                        heartRate: transferData.heartRate
                    )
                    savedCount += 1
                }
            }
            
            print("📱 Received and saved \(savedCount) workouts from watch")
            lastSyncDate = Date()
            
        } catch {
            print("❌ Failed to decode all workouts data from watch: \(error.localizedDescription)")
        }
    }
    
    private func handleWorkoutRequest() {
        guard let workoutDataManager = workoutDataManager else {
            print("❌ No WorkoutDataManager available to send workouts")
            return
        }
        
        // Send all workouts to watch
        let allWorkouts = workoutDataManager.workouts.map { WorkoutTransferData(from: $0) }
        
        do {
            let data = try JSONEncoder().encode(allWorkouts)
            let message = [WatchConnectivityKeys.sendAllWorkouts: data]
            
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("❌ Failed to send all workouts to watch: \(error.localizedDescription)")
            }
            
            print("📱 Sent \(allWorkouts.count) workouts to watch")
        } catch {
            print("❌ Failed to encode all workouts data: \(error.localizedDescription)")
        }
    }
}
