//
//  WorkoutDataManager.swift
//  MARCH
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
    
    @NSManaged public var id: UUID?
    @NSManaged public var calories: Double
    @NSManaged public var date: Date?
    @NSManaged public var distance: Double
    @NSManaged public var duration: Double
    @NSManaged public var heartRate: Double
    @NSManaged public var ruckWeight: Double
    @NSManaged public var programId: String? // Store as String, convert to UUID
    @NSManaged public var programWorkoutDay: Int16 // Which day in program
    @NSManaged public var challengeId: String? // Store as String, convert to UUID
    @NSManaged public var challengeDay: Int16 // Which day in challenge
}

class WorkoutDataManager: ObservableObject {
    static let shared = WorkoutDataManager()
    
    @Published var workouts: [WorkoutEntity] = []
    @Published var lastSavedWorkoutURI: URL?
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        // Create the model programmatically
        let model = NSManagedObjectModel()
        
        // Create WorkoutEntity
        let entity = NSEntityDescription()
        entity.name = "WorkoutEntity"
        entity.managedObjectClassName = "WorkoutEntity"
        
        // Add attributes
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = true
        
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
        
        // Add program tracking attributes
        let programIdAttribute = NSAttributeDescription()
        programIdAttribute.name = "programId"
        programIdAttribute.attributeType = .stringAttributeType
        programIdAttribute.isOptional = true
        
        let programWorkoutDayAttribute = NSAttributeDescription()
        programWorkoutDayAttribute.name = "programWorkoutDay"
        programWorkoutDayAttribute.attributeType = .integer16AttributeType
        programWorkoutDayAttribute.isOptional = true
        programWorkoutDayAttribute.defaultValue = 0
        
        // Add challenge tracking attributes
        let challengeIdAttribute = NSAttributeDescription()
        challengeIdAttribute.name = "challengeId"
        challengeIdAttribute.attributeType = .stringAttributeType
        challengeIdAttribute.isOptional = true
        
        let challengeDayAttribute = NSAttributeDescription()
        challengeDayAttribute.name = "challengeDay"
        challengeDayAttribute.attributeType = .integer16AttributeType
        challengeDayAttribute.isOptional = true
        challengeDayAttribute.defaultValue = 0
        
        entity.properties = [idAttribute, dateAttribute, durationAttribute, distanceAttribute, caloriesAttribute, ruckWeightAttribute, heartRateAttribute, programIdAttribute, programWorkoutDayAttribute, challengeIdAttribute, challengeDayAttribute]
        model.entities = [entity]
        
        let container = NSPersistentContainer(name: "RuckTrackerData", managedObjectModel: model)
        // Enable lightweight migration so adding fields like `id` won't break existing installs.
        for description in container.persistentStoreDescriptions {
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
            } else {
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
    @discardableResult
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
    ) -> UUID {
        print("🔵 Program Workout Day: \(programWorkoutDay?.description ?? "NONE")")
        print("🔵 Challenge ID: \(challengeId?.uuidString ?? "NONE")")
        print("🔵 Challenge Day: \(challengeDay?.description ?? "NONE")")
        print("🔵 Current workout count BEFORE save: \(workouts.count)")
        
        let workout = WorkoutEntity(context: context)
        let workoutId = UUID()
        workout.id = workoutId
        workout.date = date
        workout.duration = duration
        workout.distance = distance
        workout.calories = calories
        workout.ruckWeight = ruckWeight
        workout.heartRate = heartRate
        
        // Add program metadata if provided
        if let programId = programId {
            workout.programId = programId.uuidString
            print("🔵 Set workout.programId = \(programId.uuidString)")
        }
        if let day = programWorkoutDay {
            workout.programWorkoutDay = Int16(day)
            print("🔵 Set workout.programWorkoutDay = \(day)")
        }
        
        // Add challenge metadata if provided
        if let challengeId = challengeId {
            workout.challengeId = challengeId.uuidString
            print("🔵 Set workout.challengeId = \(challengeId.uuidString)")
        }
        if let day = challengeDay {
            workout.challengeDay = Int16(day)
            print("🔵 Set workout.challengeDay = \(day)")
        }
        
        saveContext()
        print("🔵 Context saved to CoreData")
        
        // Track the most recent saved workout for sharing and deep links
        lastSavedWorkoutURI = workout.objectID.uriRepresentation()
        
        fetchWorkouts() // Refresh the list
        print("🔵 Current workout count AFTER save: \(workouts.count)")
        print("🔵 ===== WORKOUT SAVED =====\n")
        return workoutId
    }
    
    /// Fetch all workouts ordered by date (newest first)
    func fetchWorkouts() {
        let request: NSFetchRequest<WorkoutEntity> = WorkoutEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutEntity.date, ascending: false)]
        
        do {
            workouts = try context.fetch(request)
        } catch {
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
    func saveContext() {
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
        print("\n🔴 ===== DELETING PROGRAM WORKOUTS =====")
        print("🔴 Program ID: \(programId.uuidString)")
        print("🔴 Total workouts BEFORE delete: \(workouts.count)")
        
        let request: NSFetchRequest<WorkoutEntity> = WorkoutEntity.fetchRequest()
        request.predicate = NSPredicate(format: "programId == %@", programId.uuidString)
        
        do {
            let workoutsToDelete = try context.fetch(request)
            let count = workoutsToDelete.count
            
            print("🔴 Found \(count) workouts to delete for this program")
            for (index, workout) in workoutsToDelete.enumerated() {
                print("🔴 Deleting workout \(index + 1): Day \(workout.programWorkoutDay), Date: \(workout.date?.formatted() ?? "nil")")
                context.delete(workout)
            }
            
            saveContext()
            print("🔴 Context saved after deletion")
            
            fetchWorkouts()
            print("🔴 Total workouts AFTER delete: \(workouts.count)")
            print("🔴 ===== DELETION COMPLETE =====\n")
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
    
    // MARK: - Testing Helpers
    
    /// Create a sample workout for testing (can be called manually)
    func createSampleWorkout() {
        let sampleDate = Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        saveWorkout(
            date: sampleDate,
            duration: 3600, // 1 hour
            distance: 3.5,  // 3.5 miles
            calories: 450,  // 450 calories
            ruckWeight: 25, // 25 lbs
            heartRate: 135  // 135 bpm
        )
        print("📝 Created sample workout for testing")
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
