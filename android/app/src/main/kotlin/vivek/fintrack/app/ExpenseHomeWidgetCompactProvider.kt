package vivek.fintrack.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.DisplayMetrics
import android.widget.RemoteViews

class ExpenseHomeWidgetCompactProvider : AppWidgetProvider() {

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

        val opts = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWdDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180)
        val dm: DisplayMetrics = context.resources.displayMetrics
        val padDp = 3 + 3 + 12 + 12
        val textPx = ((minWdDp - padDp).coerceAtLeast(80) * dm.density).toInt()
            .coerceAtLeast((64f * dm.density).toInt())

        try {
            val views = RemoteViews(context.packageName, R.layout.expense_home_widget_compact)

            WidgetTextFit.setTextViewTextSingleLineFit(
                views,
                R.id.widget_compact_period,
                periodTitle,
                textPx,
                15f,
                10f,
                dm,
            )
            WidgetTextFit.setTextViewTextSingleLineFit(
                views,
                R.id.widget_compact_expense,
                expenseDisplay,
                textPx,
                22f,
                11f,
                dm,
            )

            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 10_000,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_compact_container, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (_: Exception) {
            val fallback = RemoteViews(context.packageName, R.layout.expense_home_widget_compact)
            val w = (160 * dm.density).toInt()
            WidgetTextFit.setTextViewTextSingleLineFit(
                fallback,
                R.id.widget_compact_period,
                "—",
                w,
                15f,
                10f,
                dm,
            )
            WidgetTextFit.setTextViewTextSingleLineFit(
                fallback,
                R.id.widget_compact_expense,
                expenseDisplay,
                w,
                22f,
                11f,
                dm,
            )
            appWidgetManager.updateAppWidget(appWidgetId, fallback)
        }
    }
}
