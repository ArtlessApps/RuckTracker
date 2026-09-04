package com.artless.rucktracker.di

import android.content.Context
import androidx.room.Room
import com.artless.rucktracker.data.local.AppDatabase
import com.artless.rucktracker.data.remote.SupabaseClientProvider
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideSupabaseClient(): SupabaseClient = SupabaseClientProvider.client

    @Provides
    @Singleton
    fun provideAppDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "rucktracker.db")
            .fallbackToDestructiveMigration()
            .build()

    @Provides
    fun provideWorkoutDao(db: AppDatabase) = db.workoutDao()

    @Provides
    fun provideRoutePointDao(db: AppDatabase) = db.routePointDao()
}
