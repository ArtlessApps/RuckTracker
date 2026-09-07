package com.artless.rucktracker.share

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.util.Log
import androidx.core.content.FileProvider
import com.artless.rucktracker.data.local.WorkoutEntity
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import java.io.FileOutputStream
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ShareCardRenderer @Inject constructor(
    @ApplicationContext private val context: Context
) {
    fun renderWorkoutCard(workout: WorkoutEntity, username: String?): Bitmap {
        val width = 1080
        val height = 1920
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.parseColor("#000000"))

        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 72f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val statPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#00C896")
            textSize = 56f
        }
        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#8CA6C1")
            textSize = 40f
        }

        canvas.drawText("MARCH", 80f, 200f, titlePaint)
        canvas.drawText(username ?: "Rucker", 80f, 300f, labelPaint)
        canvas.drawText(String.format("%.2f mi", workout.distance), 80f, 500f, statPaint)
        canvas.drawText("Distance", 80f, 560f, labelPaint)
        canvas.drawText(String.format("%.0f lb ruck", workout.ruckWeight), 80f, 720f, statPaint)
        canvas.drawText("Load", 80f, 780f, labelPaint)
        canvas.drawText(String.format("%.0f cal", workout.calories), 80f, 940f, statPaint)
        canvas.drawText("Calories", 80f, 1000f, labelPaint)
        val tonnage = workout.distance * workout.ruckWeight
        canvas.drawText(String.format("%.0f lb·mi", tonnage), 80f, 1160f, statPaint)
        canvas.drawText("Tonnage", 80f, 1220f, labelPaint)

        return bitmap
    }

    /**
     * @param launchContext Activity context preferred (e.g. LocalContext). Falls back to
     * application context with NEW_TASK if none is provided.
     */
    fun shareWorkout(
        workout: WorkoutEntity,
        username: String?,
        launchContext: Context = context
    ) {
        val bitmap = renderWorkoutCard(workout, username)
        try {
            val cacheDir = File(context.cacheDir, "share")
            cacheDir.mkdirs()
            val file = File(cacheDir, "march_workout_${workout.id}.png")
            FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, "Just finished a ruck with MARCH!")
                clipData = ClipData.newUri(context.contentResolver, "MARCH workout", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(intent, "Share your ruck").apply {
                // ApplicationContext requires NEW_TASK; harmless on Activity contexts too.
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            launchContext.startActivity(chooser)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to share workout card", e)
        } finally {
            bitmap.recycle()
        }
    }

    private companion object {
        const val TAG = "ShareCardRenderer"
    }
}
