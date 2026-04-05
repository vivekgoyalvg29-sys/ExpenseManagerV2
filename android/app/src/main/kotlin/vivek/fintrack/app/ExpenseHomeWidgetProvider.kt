package vivek.fintrack.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.SweepGradient
import android.os.Build
import android.os.Bundle
import android.util.DisplayMetrics
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import kotlin.math.min

class ExpenseHomeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        appWidgetIds.forEach { updateAppWidget(context, appWidgetManager, it, prefs) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        updateAppWidget(context, appWidgetManager, appWidgetId, prefs)
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        prefs: android.content.SharedPreferences,
    ) {
        val periodTitle = HomeWidgetPreferences.periodTitle(prefs)
        val expenseDisplay = HomeWidgetPreferences.expenseDisplay(prefs)
        val calendarDay = HomeWidgetPreferences.calendarDay(prefs)
        val paceVisible = HomeWidgetPreferences.paceVisible(prefs)
        val paceLabel = HomeWidgetPreferences.paceLabel(prefs)
        val paceIsHigh = HomeWidgetPreferences.paceIsHigh(prefs)
        val barProgress = HomeWidgetPreferences.barProgressThousandths(prefs)
        val gaugeProgress = HomeWidgetPreferences.gaugeProgressThousandths(prefs, barProgress)

        val opts = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWdDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 280)
        val dm = context.resources.displayMetrics
        val totalPx = (minWdDp * dm.density).toInt().coerceAtLeast(1)

        val paceReserveDp = if (paceVisible && paceLabel.isNotEmpty()) 84f else 12f
        val reservedHorizDp = 3 + 3 + 3 + 3 + 6 + 8 + 48 + 8 + 10 + paceReserveDp
        val textColumnPx = (totalPx - reservedHorizDp * dm.density).toInt()
            .coerceAtLeast((72f * dm.density).toInt())

        try {
            val views = RemoteViews(context.packageName, R.layout.expense_home_widget)

            views.setTextViewText(R.id.widget_calendar_day, calendarDay.toString())

            WidgetTextFit.setTextViewTextSingleLineFit(
                views,
                R.id.widget_period,
                periodTitle,
                textColumnPx,
                15f,
                10f,
                dm,
            )
            WidgetTextFit.setTextViewTextSingleLineFit(
                views,
                R.id.widget_expense,
                expenseDisplay,
                textColumnPx,
                24f,
                11f,
                dm,
            )

            val paceColor = ContextCompat.getColor(context, R.color.widget_pace_green)
            if (paceVisible && paceLabel.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_pace, View.VISIBLE)
                val decorated = if (paceIsHigh) "↑ $paceLabel" else "✓ $paceLabel"
                views.setTextViewText(R.id.widget_pace, decorated)
                views.setInt(R.id.widget_pace, "setTextColor", paceColor)
            } else {
                views.setViewVisibility(R.id.widget_pace, View.GONE)
            }

            views.setProgressBar(R.id.widget_bar, 1000, barProgress, false)

            val gaugeRatio = gaugeProgress / 1000f
            val gaugeW = (minWdDp * dm.density).toInt()
                .coerceIn((110 * dm.density).toInt(), (min(340, minWdDp) * dm.density).toInt())
            val gaugeH = (26 * dm.density).toInt().coerceIn((22 * dm.density).toInt(), (38 * dm.density).toInt())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    views.setViewVisibility(R.id.widget_gauge, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_gauge_fallback, View.GONE)
                    views.setImageViewBitmap(R.id.widget_gauge, buildGaugeBitmap(gaugeW, gaugeH, gaugeRatio))
                } catch (_: Exception) {
                    views.setViewVisibility(R.id.widget_gauge, View.GONE)
                    views.setViewVisibility(R.id.widget_gauge_fallback, View.VISIBLE)
                    views.setProgressBar(R.id.widget_gauge_fallback, 1000, gaugeProgress, false)
                }
            } else {
                views.setViewVisibility(R.id.widget_gauge, View.GONE)
                views.setViewVisibility(R.id.widget_gauge_fallback, View.VISIBLE)
                views.setProgressBar(R.id.widget_gauge_fallback, 1000, gaugeProgress, false)
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (_: Exception) {
            val fallback = RemoteViews(context.packageName, R.layout.expense_home_widget)
            val w = (200 * dm.density).toInt()
            WidgetTextFit.setTextViewTextSingleLineFit(
                fallback,
                R.id.widget_period,
                "—",
                w,
                15f,
                10f,
                dm,
            )
            WidgetTextFit.setTextViewTextSingleLineFit(
                fallback,
                R.id.widget_expense,
                expenseDisplay,
                w,
                24f,
                11f,
                dm,
            )
            fallback.setViewVisibility(R.id.widget_pace, View.GONE)
            fallback.setViewVisibility(R.id.widget_gauge, View.GONE)
            fallback.setViewVisibility(R.id.widget_gauge_fallback, View.GONE)
            appWidgetManager.updateAppWidget(appWidgetId, fallback)
        }
    }

    private fun buildGaugeBitmap(width: Int, height: Int, progress: Float): Bitmap {
        val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cx = width / 2f
        val cy = height * 0.92f
        val radius = min(width, height) * 0.38f
        val rect = RectF(cx - radius, cy - radius, cx + radius, cy + radius)
        val stroke = 3.5f.coerceAtLeast(2.4f * width / 168f)

        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0x38000000
            style = Paint.Style.STROKE
            this.strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawArc(rect, 180f, 180f, false, track)

        val sweep = 180f * progress.coerceIn(0f, 1f)
        if (sweep <= 0.5f) return bmp

        val colors = intArrayOf(0xFFF97316.toInt(), 0xFFEAB308.toInt(), 0xFF22C55E.toInt())
        val shader = SweepGradient(cx, cy, colors, floatArrayOf(0f, 0.5f, 1f))
        val matrix = Matrix()
        matrix.postRotate(180f, cx, cy)
        shader.setLocalMatrix(matrix)

        val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            this.strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
            setShader(shader)
        }
        canvas.drawArc(rect, 180f, sweep, false, arc)
        return bmp
    }
}
