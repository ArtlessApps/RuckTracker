package com.artless.rucktracker.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.artless.rucktracker.ui.auth.AppGateState
import com.artless.rucktracker.ui.auth.AuthScreen
import com.artless.rucktracker.ui.auth.AuthViewModel
import com.artless.rucktracker.ui.onboarding.OnboardingScreen
import com.artless.rucktracker.ui.programs.ProgramsCatalogScreen
import com.artless.rucktracker.ui.splash.SplashScreen
import com.artless.rucktracker.ui.workout.ActiveWorkoutScreen
import com.artless.rucktracker.ui.workout.PostWorkoutSummaryScreen
import com.artless.rucktracker.ui.workout.StartRuckScreen
import com.artless.rucktracker.ui.workout.WorkoutViewModel

private object Routes {
    const val SPLASH = "splash"
    const val AUTH = "auth"
    const val ONBOARDING = "onboarding"
    const val MAIN = "main"
    const val PROGRAMS = "programs"
    const val START_RUCK = "start_ruck"
    const val ACTIVE_WORKOUT = "active_workout"
    const val POST_WORKOUT = "post_workout"
}

@Composable
fun AppNav(navController: NavHostController = rememberNavController()) {
    val authViewModel: AuthViewModel = hiltViewModel()
    val workoutViewModel: WorkoutViewModel = hiltViewModel()
    val gateState by authViewModel.gateState.collectAsStateWithLifecycle()
    val completedWorkout by workoutViewModel.completedWorkout.collectAsStateWithLifecycle()

    LaunchedEffect(gateState) {
        val destination = when (gateState) {
            AppGateState.Loading -> Routes.SPLASH
            AppGateState.SignedOut -> Routes.AUTH
            AppGateState.NeedsOnboarding -> Routes.ONBOARDING
            is AppGateState.Ready -> Routes.MAIN
        }
        navController.navigate(destination) {
            popUpTo(0) { inclusive = true }
            launchSingleTop = true
        }
    }

    LaunchedEffect(completedWorkout) {
        if (completedWorkout != null) {
            navController.navigate(Routes.POST_WORKOUT) {
                launchSingleTop = true
            }
        }
    }

    NavHost(navController = navController, startDestination = Routes.SPLASH) {
        composable(Routes.SPLASH) { SplashScreen() }
        composable(Routes.AUTH) { AuthScreen(viewModel = authViewModel) }
        composable(Routes.ONBOARDING) {
            OnboardingScreen(onComplete = {
                authViewModel.markOnboardingFinished()
                navController.navigate(Routes.MAIN) {
                    popUpTo(0) { inclusive = true }
                }
            })
        }
        composable(Routes.MAIN) {
            MainTabScaffold(
                onStartRuck = { navController.navigate(Routes.START_RUCK) },
                onOpenPrograms = { navController.navigate(Routes.PROGRAMS) },
                onBuildPlan = authViewModel::returnToOnboarding
            )
        }
        composable(Routes.PROGRAMS) {
            ProgramsCatalogScreen(onBack = { navController.popBackStack() })
        }
        composable(Routes.START_RUCK) {
            StartRuckScreen(
                viewModel = workoutViewModel,
                onStarted = {
                    navController.navigate(Routes.ACTIVE_WORKOUT) {
                        popUpTo(Routes.START_RUCK) { inclusive = true }
                    }
                },
                onBack = { navController.popBackStack() }
            )
        }
        composable(Routes.ACTIVE_WORKOUT) {
            ActiveWorkoutScreen(
                viewModel = workoutViewModel,
                onEnded = { /* handled via completedWorkout flow */ }
            )
        }
        composable(Routes.POST_WORKOUT) {
            PostWorkoutSummaryScreen(
                viewModel = workoutViewModel,
                onDone = {
                    workoutViewModel.clearCompletedWorkout()
                    navController.navigate(Routes.MAIN) {
                        popUpTo(Routes.MAIN) { inclusive = true }
                    }
                }
            )
        }
    }
}

fun NavHostController.navigateToStartRuck() {
    navigate(Routes.START_RUCK)
}
