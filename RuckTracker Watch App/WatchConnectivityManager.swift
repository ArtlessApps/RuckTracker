//
//  WatchConnectivityManager.swift
//  RuckTracker Watch App
//
//  Manages communication between Apple Watch and iPhone apps
//

import Foundation
import WatchConnectivity
import CoreData
import Combine

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isPhoneReachable = false
    @Published var lastSyncDate: Date?
    
    private var workoutDataManager: WorkoutDataManager?
    private var cancellables = Set<AnyCancellable>()
    
    // Workouts encoded before session activation completes are held here and
    // flushed once activationDidCompleteWith fires.
    private var pendingWorkoutData: [Data] = []
    
    private var isSessionActivated: Bool {
        WCSession.isSupported() && WCSession.default.activationState == .activated
    }
    
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
    
    /// Send a single workout to the phone.
    /// Uses sendMessage (instant) when the phone is reachable; falls back to
    /// transferUserInfo (guaranteed queued delivery) when it is not.
    /// If the WCSession is not yet activated the data is held in pendingWorkoutData
    /// and flushed automatically once activationDidCompleteWith fires.
    func sendWorkoutToPhone(_ workout: WorkoutEntity) {
        guard let data = try? JSONEncoder().encode(WorkoutTransferData(from: workout)) else {
            print("❌ Failed to encode workout data")
            return
        }
        transferWorkoutData(data, date: workout.date)
    }
    
    private func transferWorkoutData(_ data: Data, date: Date?) {
        guard isSessionActivated else {
            print("⌚ WCSession not yet activated — queuing workout for later delivery")
            pendingWorkoutData.append(data)
            return
        }
        
        if isPhoneReachable {
            WCSession.default.sendMessage([WatchConnectivityKeys.workoutData: data], replyHandler: nil) { [weak self] error in
                print("❌ sendMessage failed (\(error.localizedDescription)) — queuing via transferUserInfo")
                guard self?.isSessionActivated == true else { return }
                WCSession.default.transferUserInfo([WatchConnectivityKeys.workoutData: data])
            }
            print("⌚ Sent workout to phone via sendMessage: \(date?.formatted() ?? "unknown date")")
        } else {
            WCSession.default.transferUserInfo([WatchConnectivityKeys.workoutData: data])
            print("⌚ Queued workout via transferUserInfo (phone not reachable): \(date?.formatted() ?? "unknown date")")
        }
        
        lastSyncDate = Date()
    }
    
    private func flushPendingWorkouts() {
        guard !pendingWorkoutData.isEmpty else { return }
        print("⌚ Flushing \(pendingWorkoutData.count) pending workout(s) after session activation")
        let toSend = pendingWorkoutData
        pendingWorkoutData.removeAll()
        for data in toSend {
            transferWorkoutData(data, date: nil)
        }
    }
    
    /// Send all workouts to the phone
    func sendAllWorkoutsToPhone() {
        guard isPhoneReachable else {
            print("⌚ Phone not reachable, cannot send workouts")
            return
        }
        
        guard let workoutDataManager = workoutDataManager else {
            print("❌ No WorkoutDataManager available")
            return
        }
        
        let allWorkouts = workoutDataManager.workouts.map { WorkoutTransferData(from: $0) }
        
        do {
            let data = try JSONEncoder().encode(allWorkouts)
            let message = [WatchConnectivityKeys.sendAllWorkouts: data]
            
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("❌ Failed to send all workouts to phone: \(error.localizedDescription)")
            }
            
            print("⌚ Sent \(allWorkouts.count) workouts to phone")
            lastSyncDate = Date()
        } catch {
            print("❌ Failed to encode all workouts data: \(error.localizedDescription)")
        }
    }
    
    /// Request all workouts from the phone
    func requestWorkoutsFromPhone() {
        guard isPhoneReachable else {
            print("⌚ Phone not reachable, cannot request workouts")
            return
        }
        
        let message = [WatchConnectivityKeys.requestWorkouts: true]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ Failed to request workouts from phone: \(error.localizedDescription)")
        }
        
        print("⌚ Requested workouts from phone")
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ WatchConnectivity activation error: \(error.localizedDescription)")
            }
            switch activationState {
            case .activated:
                print("⌚ WatchConnectivity activated — reachable: \(session.isReachable), pending: \(self.pendingWorkoutData.count)")
                self.isPhoneReachable = session.isReachable
                self.flushPendingWorkouts()
            case .inactive:
                print("⌚ WatchConnectivity inactive")
                self.isPhoneReachable = false
            case .notActivated:
                print("❌ WatchConnectivity NOT activated\(error.map { " — \($0.localizedDescription)" } ?? "")")
                self.isPhoneReachable = false
            @unknown default:
                print("⌚ WatchConnectivity unknown state")
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
            print("⌚ Phone reachability changed: \(session.isReachable)")
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
        // Handle workout data from phone
        if let workoutData = message[WatchConnectivityKeys.workoutData] as? Data {
            handleReceivedWorkoutData(workoutData)
        }
        
        // Handle multiple workouts from phone
        if let allWorkoutsData = message[WatchConnectivityKeys.sendAllWorkouts] as? Data {
            handleReceivedAllWorkouts(allWorkoutsData)
        }
        
        // Handle workout request from phone
        if let _ = message[WatchConnectivityKeys.requestWorkouts] as? Bool {
            handleWorkoutRequest()
        }
        
        // Handle start workout command from phone
        if let _ = message[WatchConnectivityKeys.startWorkout] as? Bool {
            handleStartWorkoutCommand()
        }
    }
    
    private func handleReceivedWorkoutData(_ data: Data) {
        do {
            let transferData = try JSONDecoder().decode(WorkoutTransferData.self, from: data)
            
            guard let workoutDataManager = workoutDataManager else {
                print("❌ No WorkoutDataManager available to save workout")
                return
            }
            
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
                    heartRate: transferData.heartRate,
                    elevationGain: transferData.elevationGain
                )
                
                print("⌚ Received and saved workout from phone: \(transferData.date.formatted())")
                lastSyncDate = Date()
            } else {
                print("⌚ Workout already exists, skipping duplicate")
            }
            
        } catch {
            print("❌ Failed to decode workout data from phone: \(error.localizedDescription)")
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
                        heartRate: transferData.heartRate,
                        elevationGain: transferData.elevationGain
                    )
                    savedCount += 1
                }
            }
            
            print("⌚ Received and saved \(savedCount) workouts from phone")
            lastSyncDate = Date()
            
        } catch {
            print("❌ Failed to decode all workouts data from phone: \(error.localizedDescription)")
        }
    }
    
    private func handleWorkoutRequest() {
        // Send all workouts to phone
        sendAllWorkoutsToPhone()
    }
    
    private func handleStartWorkoutCommand() {
        print("⌚ Received start workout command from phone")
        // This would typically trigger the workout start in the watch app
        // For now, we'll just log it - the actual implementation would depend on
        // how the watch app is structured to handle external start commands
        NotificationCenter.default.post(name: .startWorkoutFromPhone, object: nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let startWorkoutFromPhone = Notification.Name("startWorkoutFromPhone")
}
