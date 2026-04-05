package vivek.fintrack.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class ExpenseHomeWidgetCompactProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val periodTitle = HomeWidgetPreferences.periodTitle(prefs)
        val expenseDisplay = HomeWidgetPreferences.expenseDisplay(prefs)

        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.expense_home_widget_compact)
                views.setTextViewText(R.id.widget_compact_period, periodTitle)
                views.setTextViewText(R.id.widget_compact_expense, expenseDisplay)

                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_MAIN
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId + 10_000,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_compact_container, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
                val fallback = RemoteViews(context.packageName, R.layout.expense_home_widget_compact)
                fallback.setTextViewText(R.id.widget_compact_period, "—")
                fallback.setTextViewText(R.id.widget_compact_expense, expenseDisplay)
                appWidgetManager.updateAppWidget(widgetId, fallback)
            }
        }
    }
}
