//
//  WorkoutDataManager.swift
//  RuckTracker Watch App
//
//  CoreData manager for local workout storage
//

import Foundation
import CoreData
import Combine

// MARK: - WorkoutEntity Class (Manual Definition)
@objc(WorkoutEntity)
public class WorkoutEntity: NSManagedObject {
    
}

extension WorkoutEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutEntity> {
        return NSFetchRequest<WorkoutEntity>(entityName: "WorkoutEntity")
    }
    
    @NSManaged public var calories: Double
    @NSManaged public var date: Date?
    @NSManaged public var distance: Double
    @NSManaged public var duration: Double
    @NSManaged public var heartRate: Double
    @NSManaged public var ruckWeight: Double
    
    // Program tracking
    @NSManaged public var programId: String?
    @NSManaged public var programWorkoutDay: Int16
    
    // Challenge tracking
    @NSManaged public var challengeId: String?
    @NSManaged public var challengeDay: Int16
}

class WorkoutDataManager: ObservableObject {
    static let shared = WorkoutDataManager()
    
    @Published var workouts: [WorkoutEntity] = []
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        // Create the model programmatically
        let model = NSManagedObjectModel()
        
        // Create WorkoutEntity
        let entity = NSEntityDescription()
        entity.name = "WorkoutEntity"
        entity.managedObjectClassName = "WorkoutEntity"
        
        // Add attributes
        let dateAttribute = NSAttributeDescription()
        dateAttribute.name = "date"
        dateAttribute.attributeType = .dateAttributeType
        dateAttribute.isOptional = false
        
        let durationAttribute = NSAttributeDescription()
        durationAttribute.name = "duration"
        durationAttribute.attributeType = .doubleAttributeType
        durationAttribute.isOptional = false
        durationAttribute.defaultValue = 0.0
        
        let distanceAttribute = NSAttributeDescription()
        distanceAttribute.name = "distance"
        distanceAttribute.attributeType = .doubleAttributeType
        distanceAttribute.isOptional = false
        distanceAttribute.defaultValue = 0.0
        
        let caloriesAttribute = NSAttributeDescription()
        caloriesAttribute.name = "calories"
        caloriesAttribute.attributeType = .doubleAttributeType
        caloriesAttribute.isOptional = false
        caloriesAttribute.defaultValue = 0.0
        
        let ruckWeightAttribute = NSAttributeDescription()
        ruckWeightAttribute.name = "ruckWeight"
        ruckWeightAttribute.attributeType = .doubleAttributeType
        ruckWeightAttribute.isOptional = false
        ruckWeightAttribute.defaultValue = 0.0
        
        let heartRateAttribute = NSAttributeDescription()
        heartRateAttribute.name = "heartRate"
        heartRateAttribute.attributeType = .doubleAttributeType
        heartRateAttribute.isOptional = false
        heartRateAttribute.defaultValue = 0.0
        
        // Program tracking attributes
        let programIdAttribute = NSAttributeDescription()
        programIdAttribute.name = "programId"
        programIdAttribute.attributeType = .stringAttributeType
        programIdAttribute.isOptional = true
        
        let programWorkoutDayAttribute = NSAttributeDescription()
        programWorkoutDayAttribute.name = "programWorkoutDay"
        programWorkoutDayAttribute.attributeType = .integer16AttributeType
        programWorkoutDayAttribute.isOptional = true
        programWorkoutDayAttribute.defaultValue = 0
        
        // Challenge tracking attributes
        let challengeIdAttribute = NSAttributeDescription()
        challengeIdAttribute.name = "challengeId"
        challengeIdAttribute.attributeType = .stringAttributeType
        challengeIdAttribute.isOptional = true
        
        let challengeDayAttribute = NSAttributeDescription()
        challengeDayAttribute.name = "challengeDay"
        challengeDayAttribute.attributeType = .integer16AttributeType
        challengeDayAttribute.isOptional = true
        challengeDayAttribute.defaultValue = 0
        
        entity.properties = [dateAttribute, durationAttribute, distanceAttribute, caloriesAttribute, ruckWeightAttribute, heartRateAttribute, programIdAttribute, programWorkoutDayAttribute, challengeIdAttribute, challengeDayAttribute]
        model.entities = [entity]
        
        let container = NSPersistentContainer(name: "RuckTrackerData", managedObjectModel: model)
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("❌ CoreData error: \(error), \(error.userInfo)")
            } else {
                print("✅ CoreData loaded successfully")
            }
        }
        
        // Enable automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private init() {
        fetchWorkouts()
    }
    
    // MARK: - CRUD Operations
    
    /// Save a new workout to CoreData
    func saveWorkout(
        date: Date,
        duration: TimeInterval,
        distance: Double,
        calories: Double,
        ruckWeight: Double,
        heartRate: Double,
        programId: UUID? = nil,
        programWorkoutDay: Int? = nil,
        challengeId: UUID? = nil,
        challengeDay: Int? = nil
    ) {
        let workout = WorkoutEntity(context: context)
        workout.date = date
        workout.duration = duration
        workout.distance = distance
        workout.calories = calories
        workout.ruckWeight = ruckWeight
        workout.heartRate = heartRate
        
        // Add program metadata if provided
        if let programId = programId {
            workout.programId = programId.uuidString
        }
        if let day = programWorkoutDay {
            workout.programWorkoutDay = Int16(day)
        }
        
        // Add challenge metadata if provided
        if let challengeId = challengeId {
            workout.challengeId = challengeId.uuidString
        }
        if let day = challengeDay {
            workout.challengeDay = Int16(day)
        }
        
        saveContext()
        fetchWorkouts() // Refresh the list
        
        print("💾 Saved workout: \(String(format: "%.2f", distance))mi, \(Int(calories))cal, \(Int(ruckWeight))lbs")
    }
    
    /// Fetch all workouts ordered by date (newest first)
    func fetchWorkouts() {
        let request: NSFetchRequest<WorkoutEntity> = WorkoutEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutEntity.date, ascending: false)]
        
        do {
            workouts = try context.fetch(request)
            print("📊 Fetched \(workouts.count) workouts from CoreData")
        } catch {
            print("❌ Failed to fetch workouts: \(error)")
            workouts = []
        }
    }
    
    /// Delete a specific workout
    func deleteWorkout(_ workout: WorkoutEntity) {
        context.delete(workout)
        saveContext()
        fetchWorkouts()
        
        print("🗑️ Deleted workout from \(workout.date?.formatted() ?? "unknown date")")
    }
    
    /// Delete all workouts (for testing or reset)
    func deleteAllWorkouts() {
        let request: NSFetchRequest<NSFetchRequestResult> = WorkoutEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            saveContext()
            fetchWorkouts()
            print("🗑️ Deleted all workouts")
        } catch {
            print("❌ Failed to delete all workouts: \(error)")
        }
    }
    
    // MARK: - Save Context
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("❌ Failed to save context: \(error)")
            }
        }
    }
    
    // MARK: - Enrollment-Related Deletion
    
    /// Delete all workouts associated with a specific challenge
    func deleteWorkoutsForChallenge(_ challengeId: UUID) {
        let request: NSFetchRequest<WorkoutEntity> = WorkoutEntity.fetchRequest()
        request.predicate = NSPredicate(format: "challengeId == %@", challengeId.uuidString)
        
        do {
            let workoutsToDelete = try context.fetch(request)
            let count = workoutsToDelete.count
            
            for workout in workoutsToDelete {
                context.delete(workout)
            }
            
            saveContext()
            fetchWorkouts()
            
            print("🗑️ Deleted \(count) workouts for challenge: \(challengeId)")
        } catch {
            print("❌ Failed to delete challenge workouts: \(error)")
        }
    }
    
    /// Delete all workouts associated with a specific program
    func deleteWorkoutsForProgram(_ programId: UUID) {
        let request: NSFetchRequest<WorkoutEntity> = WorkoutEntity.fetchRequest()
        request.predicate = NSPredicate(format: "programId == %@", programId.uuidString)
        
        do {
            let workoutsToDelete = try context.fetch(request)
            let count = workoutsToDelete.count
            
            for workout in workoutsToDelete {
                context.delete(workout)
            }
            
            saveContext()
            fetchWorkouts()
            
            print("🗑️ Deleted \(count) workouts for program: \(programId)")
        } catch {
            print("❌ Failed to delete program workouts: \(error)")
        }
    }
    
    /// Get count of workouts for a specific challenge
    func getWorkoutCount(forChallengeId challengeId: UUID) -> Int {
        let request: NSFetchRequest<WorkoutEntity> = WorkoutEntity.fetchRequest()
        request.predicate = NSPredicate(format: "challengeId == %@", challengeId.uuidString)
        
        do {
            return try context.count(for: request)
        } catch {
            print("❌ Failed to count challenge workouts: \(error)")
            return 0
        }
    }
    
    /// Get count of workouts for a specific program
    func getWorkoutCount(forProgramId programId: UUID) -> Int {
        let request: NSFetchRequest<WorkoutEntity> = WorkoutEntity.fetchRequest()
        request.predicate = NSPredicate(format: "programId == %@", programId.uuidString)
        
        do {
            return try context.count(for: request)
        } catch {
            print("❌ Failed to count program workouts: \(error)")
            return 0
        }
    }
    
    // MARK: - Computed Properties for UI
    
    /// Get recent workouts (last 10)
    var recentWorkouts: [WorkoutEntity] {
        return Array(workouts.prefix(10))
    }
    
    /// Get total number of workouts
    var totalWorkouts: Int {
        return workouts.count
    }
    
    /// Get total distance across all workouts
    var totalDistance: Double {
        return workouts.reduce(0) { $0 + $1.distance }
    }
    
    /// Get total calories burned across all workouts
    var totalCalories: Double {
        return workouts.reduce(0) { $0 + $1.calories }
    }
    
    /// Get total workout time across all workouts
    var totalDuration: TimeInterval {
        return workouts.reduce(0) { $0 + $1.duration }
    }
    
    /// Get workouts from the last 30 days
    var recentWorkoutsThisMonth: [WorkoutEntity] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return workouts.filter { workout in
            guard let workoutDate = workout.date else { return false }
            return workoutDate >= thirtyDaysAgo
        }
    }
    
    /// Get average pace across all workouts
    var averagePace: Double? {
        let validWorkouts = workouts.filter { $0.distance > 0 && $0.duration > 0 }
        guard !validWorkouts.isEmpty else { return nil }
        
        let totalPace = validWorkouts.reduce(0.0) { total, workout in
            return total + (workout.duration / 60.0) / workout.distance
        }
        
        return totalPace / Double(validWorkouts.count)
    }
}

// MARK: - WorkoutEntity Extensions
extension WorkoutEntity {
    
    /// Formatted date string for display
    var formattedDate: String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Formatted duration string (HH:MM:SS or MM:SS)
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Formatted distance with unit (matching UserSettings)
    func formattedDistance(unit: UserSettings.DistanceUnit) -> String {
        let displayDistance = unit == .miles ? distance : distance / unit.conversionToMiles
        return String(format: "%.2f %@", displayDistance, unit.rawValue)
    }
    
    /// Formatted pace (minutes per mile)
    var formattedPace: String {
        guard distance > 0 && duration > 0 else { return "--:--" }
        let pace = (duration / 60.0) / distance // minutes per mile
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Pace color based on performance
    var paceColor: String {
        guard distance > 0 && duration > 0 else { return "gray" }
        let pace = (duration / 60.0) / distance
        
        switch pace {
        case 0..<14: return "orange"   // Too fast for sustainable rucking
        case 14..<18: return "green"   // Good rucking pace
        case 18..<25: return "yellow"  // Acceptable pace
        default: return "red"          // Too slow
        }
    }
    
    /// Weight percentage of body weight (requires UserSettings)
    func weightPercentage(bodyWeightKg: Double) -> Int {
        let bodyWeightPounds = bodyWeightKg * 2.20462
        return Int((ruckWeight / bodyWeightPounds) * 100)
    }
}
