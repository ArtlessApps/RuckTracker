package com.artless.rucktracker.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [WorkoutEntity::class, RoutePointEntity::class],
    version = 2,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun workoutDao(): WorkoutDao
    abstract fun routePointDao(): RoutePointDao
}
