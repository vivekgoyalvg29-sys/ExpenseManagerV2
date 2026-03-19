package com.example.expense_manager

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Locale
import kotlin.math.roundToInt

class ExpenseHomeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.expense_home_widget)

            val monthLabel = prefs.getString("currentPeriodLabel", "This month") ?: "This month"

            // ✅ Read as Double/Long (how home_widget stores them), then convert to Float
            val percentage = prefs.getAll()["currentMonthPercentage"]?.toString()?.toDoubleOrNull() ?: 0.0
            val expense = prefs.getAll()["currentMonthExpense"]?.toString()?.toDoubleOrNull() ?: 0.0
            val budget = prefs.getAll()["currentMonthBudget"]?.toString()?.toDoubleOrNull() ?: 0.0

            views.setTextViewText(
                R.id.widget_title,
                "$monthLabel (${percentage.roundToInt()}%)"
            )
            views.setTextViewText(R.id.widget_subtitle, "Spent vs budget")
            views.setTextViewText(R.id.widget_expense, formatCurrency(expense))
            views.setTextViewText(
                R.id.widget_budget,
                if (budget > 0.0) "of ${formatCurrency(budget)}" else "No budget"
            )

            // Tap widget → open app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                widgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun formatCurrency(value: Double): String {
        val formatter = NumberFormat.getCurrencyInstance(Locale("en", "IN"))
        formatter.maximumFractionDigits = 0
        return formatter.format(value)
    }
}
