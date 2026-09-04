package com.artless.rucktracker.domain

import com.artless.rucktracker.data.model.ExperienceLevel
import com.artless.rucktracker.data.model.RuckingGoal
import com.artless.rucktracker.data.settings.UserSettingsState
import java.util.Calendar

data class PlanSession(
    val dayOfWeek: Int,
    val weekNumber: Int,
    val title: String,
    val distanceMiles: Double,
    val ruckWeightLbs: Double,
    val description: String
)

data class GeneratedPlan(
    val goal: RuckingGoal,
    val weeks: List<List<PlanSession>>
)

object MarchPlanGenerator {
    fun generatePlan(settings: UserSettingsState): GeneratedPlan {
        val weeks = (1..4).map { week ->
            settings.preferredTrainingDays.map { day ->
                val baseDistance = when (settings.experienceLevel) {
                    ExperienceLevel.BEGINNER -> 2.0 + week * 0.5
                    ExperienceLevel.INTERMEDIATE -> 3.0 + week * 0.75
                    ExperienceLevel.ADVANCED -> 4.0 + week
                }
                val weight = when (settings.ruckingGoal) {
                    RuckingGoal.GORUCK_TOUGH, RuckingGoal.MILITARY -> 30.0 + week * 5
                    RuckingGoal.GORUCK_BASIC -> 20.0 + week * 3
                    else -> 15.0 + week * 2
                }
                PlanSession(
                    dayOfWeek = day,
                    weekNumber = week,
                    title = "Week $week Ruck",
                    distanceMiles = baseDistance,
                    ruckWeightLbs = weight,
                    description = "${settings.ruckingGoal.displayName} session"
                )
            }
        }
        return GeneratedPlan(settings.ruckingGoal, weeks)
    }

    fun dayName(dayOfWeek: Int): String = when (dayOfWeek) {
        1 -> "Sunday"; 2 -> "Monday"; 3 -> "Tuesday"; 4 -> "Wednesday"
        5 -> "Thursday"; 6 -> "Friday"; 7 -> "Saturday"; else -> "Day $dayOfWeek"
    }

    fun currentWeekSessions(plan: GeneratedPlan): List<PlanSession> {
        val weekOfMonth = Calendar.getInstance().get(Calendar.WEEK_OF_MONTH).coerceIn(1, plan.weeks.size)
        return plan.weeks.getOrElse(weekOfMonth - 1) { plan.weeks.first() }
    }
}
