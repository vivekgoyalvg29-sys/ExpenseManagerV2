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
import android.view.View
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Locale
import kotlin.math.min

class ExpenseHomeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        val periodTitle = readString(prefs, "widget_card_period_title", "—")
        val expenseDisplay = readString(prefs, "widget_expense_display", formatCurrency(readExpenseForDisplay(prefs)))
        val calendarDay = readInt(prefs, "widget_calendar_day", 1).coerceIn(1, 31)
        val paceVisible = readInt(prefs, "widget_pace_visible", 0) == 1
        val paceLabel = readString(prefs, "widget_pace_label", "")
        val paceIsHigh = readInt(prefs, "widget_pace_is_high", 0) == 1
        val barProgress = readInt(prefs, "widget_bar_progress_thousandths", 0).coerceIn(0, 1000)
        val gaugeProgress = readInt(prefs, "widget_gauge_progress_thousandths", barProgress).coerceIn(0, 1000)
        val modeShort = readString(prefs, "widget_mode_short", "")

        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.expense_home_widget)

                views.setTextViewText(R.id.widget_period, periodTitle)
                views.setTextViewText(R.id.widget_expense, expenseDisplay)
                views.setTextViewText(R.id.widget_calendar_day, calendarDay.toString())
                views.setTextViewText(R.id.widget_mode_hint, modeShort)

                if (paceVisible && paceLabel.isNotEmpty()) {
                    views.setViewVisibility(R.id.widget_pace, View.VISIBLE)
                    val decorated = if (paceIsHigh) "↑ $paceLabel" else "✓ $paceLabel"
                    views.setTextViewText(R.id.widget_pace, decorated)
                } else {
                    views.setViewVisibility(R.id.widget_pace, View.GONE)
                }

                views.setProgressBar(R.id.widget_bar, 1000, barProgress, false)

                val gaugeRatio = gaugeProgress / 1000f
                val w = (160 * context.resources.displayMetrics.density).toInt().coerceAtLeast(120)
                val h = (40 * context.resources.displayMetrics.density).toInt().coerceAtLeast(32)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        views.setViewVisibility(R.id.widget_gauge, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_gauge_fallback, View.GONE)
                        views.setImageViewBitmap(R.id.widget_gauge, buildGaugeBitmap(w, h, gaugeRatio))
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
                    widgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
                val fallback = RemoteViews(context.packageName, R.layout.expense_home_widget)
                fallback.setTextViewText(R.id.widget_period, "—")
                fallback.setTextViewText(R.id.widget_expense, expenseDisplay)
                fallback.setViewVisibility(R.id.widget_pace, View.GONE)
                fallback.setViewVisibility(R.id.widget_gauge, View.GONE)
                fallback.setViewVisibility(R.id.widget_gauge_fallback, View.GONE)
                appWidgetManager.updateAppWidget(widgetId, fallback)
            }
        }
    }

    private fun readExpenseForDisplay(prefs: android.content.SharedPreferences): Double {
        return readDouble(prefs, "expense", 0.0)
    }

    private fun readDouble(prefs: android.content.SharedPreferences, key: String, default: Double): Double {
        if (!prefs.contains(key)) return default
        val isDoubleBits = prefs.getBoolean("home_widget.double.$key", false)
        val raw = prefs.all[key] ?: return default
        if (isDoubleBits && raw is Long) {
            return java.lang.Double.longBitsToDouble(raw)
        }
        return when (raw) {
            is Double -> raw
            is Float -> raw.toDouble()
            is Int -> raw.toDouble()
            is Long -> if (isDoubleBits) java.lang.Double.longBitsToDouble(raw) else raw.toDouble()
            is String -> raw.toDoubleOrNull() ?: default
            else -> default
        }
    }

    private fun readInt(prefs: android.content.SharedPreferences, key: String, default: Int): Int {
        val raw = prefs.all[key] ?: return default
        return when (raw) {
            is Int -> raw
            is Long -> raw.toInt()
            is String -> raw.toIntOrNull() ?: default
            else -> default
        }
    }

    private fun readString(prefs: android.content.SharedPreferences, key: String, default: String): String {
        prefs.getString(key, null)?.let { return it }
        return (prefs.all[key] as? String) ?: default
    }

    private fun formatCurrency(value: Double): String {
        val formatter = NumberFormat.getCurrencyInstance(Locale("en", "IN"))
        formatter.maximumFractionDigits = 0
        return formatter.format(value)
    }

    private fun buildGaugeBitmap(width: Int, height: Int, progress: Float): Bitmap {
        val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cx = width / 2f
        val cy = height * 0.92f
        val radius = min(width, height) * 0.38f
        val rect = RectF(cx - radius, cy - radius, cx + radius, cy + radius)
        val stroke = 5f.coerceAtLeast(3f * width / 160f)

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
