import Foundation
import Combine

class WorkoutManager: ObservableObject {
    @Published var isActive = false
    @Published var isPaused = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var heartRate: Double = 119
    @Published var distance: Double = 0
    @Published var calories: Double = 0
    @Published var pace: Double = 0 // minutes per mile
    @Published var ruckWeight: Double = 20.0 // Ruck weight in pounds
    
    // Computed properties for time display
    var hours: Int { Int(elapsedTime) / 3600 }
    var minutes: Int { (Int(elapsedTime) % 3600) / 60 }
    var seconds: Int { Int(elapsedTime) % 60 }
    
    private var timer: Timer?
    private var weight: Double = 20.0
    
    // Heart rate simulation
    private var baseHeartRate: Double = 115
    
    init() {
        // Initialize weight to match ruckWeight
        self.weight = self.ruckWeight
    }
    
    func startWorkout(weight: Double) {
        self.weight = weight
        self.ruckWeight = weight
        isActive = true
        isPaused = false
        startTimer()
    }
    
    func pauseWorkout() {
        stopTimer()
        isPaused = true
        isActive = false
    }
    
    func resumeWorkout() {
        startTimer()
        isPaused = false
        isActive = true
    }
    
    func endWorkout() {
        stopTimer()
        isActive = false
        isPaused = false
        
        // Reset values
        elapsedTime = 0
        distance = 0
        calories = 0
        pace = 0
        heartRate = 119
    }
    
    func updateWeight(_ newWeight: Double) {
        self.weight = newWeight
        self.ruckWeight = newWeight // Update the published property
        // Recalculate calories with new weight
        updateCalories()
    }
    
    private func startTimer() {
        isActive = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateMetrics()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMetrics() {
        guard isActive else { return }
        
        elapsedTime += 1
        
        // Simulate distance (approximately 2.5 mph average rucking pace)
        let timeInHours = elapsedTime / 3600
        distance = timeInHours * 2.5
        
        // Calculate pace (minutes per mile)
        if distance > 0 {
            pace = (elapsedTime / 60) / distance
        }
        
        // Update calories
        updateCalories()
        
        // Simulate heart rate with realistic variation
        updateHeartRate()
    }
    
    private func updateCalories() {
        // Enhanced calorie calculation accounting for weight
        let timeInHours = elapsedTime / 3600
        let baseMET = 5.0 // Base MET for hiking
        let weightMET = weight > 15 ? 1.5 : 1.0 // Additional MET for weight
        let totalMET = baseMET + weightMET
        
        // Calories = MET × weight in kg × time in hours
        let weightInKg = 70.0 // Average person weight
        calories = totalMET * weightInKg * timeInHours
    }
    
    private func updateHeartRate() {
        // Simulate realistic heart rate during rucking
        let baseRate = 110 + (weight * 0.5) // Higher base rate with more weight
        let timeEffect = min(elapsedTime / 600, 1.0) // Gradual increase over 10 minutes
        let variability = Double.random(in: -3...3) // Random variation
        
        heartRate = baseRate + (timeEffect * 15) + variability
        heartRate = max(95, min(heartRate, 155)) // Keep in reasonable range
    }
}
