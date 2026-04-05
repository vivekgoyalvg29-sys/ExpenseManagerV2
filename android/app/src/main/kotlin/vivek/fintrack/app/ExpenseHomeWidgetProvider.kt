package vivek.fintrack.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.DisplayMetrics
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat

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

        val opts = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWdDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 280)
        val dm = context.resources.displayMetrics
        val totalPx = (minWdDp * dm.density).toInt().coerceAtLeast(1)

        // Reserve: outer padding, card padding, row padding, calendar, gaps, pace column when shown.
        val paceReserveDp = if (paceVisible && paceLabel.isNotEmpty()) 76f else 48f
        val reservedHorizDp = 3f + 3f + 3f + 3f + 6f + 8f + 48f + 8f + paceReserveDp + 4f
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
                views.setViewVisibility(R.id.widget_trailing_balance, View.GONE)
                val decorated = if (paceIsHigh) "↑ $paceLabel" else "✓ $paceLabel"
                views.setTextViewText(R.id.widget_pace, decorated)
                views.setInt(R.id.widget_pace, "setTextColor", paceColor)
            } else {
                views.setViewVisibility(R.id.widget_pace, View.GONE)
                views.setViewVisibility(R.id.widget_trailing_balance, View.VISIBLE)
            }

            views.setProgressBar(R.id.widget_bar, 1000, barProgress, false)

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
            fallback.setViewVisibility(R.id.widget_trailing_balance, View.VISIBLE)
            appWidgetManager.updateAppWidget(appWidgetId, fallback)
        }
    }
}
