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

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        appWidgetIds.forEach { widgetId ->

            val views = RemoteViews(context.packageName, R.layout.expense_home_widget)

            // SAFE READ
            val monthLabel = prefs.getString("flutter.currentPeriodLabel", "This month") ?: "This month"
            val percentage = prefs.getFloat("flutter.currentMonthPercentage", 0f)
            val expense = prefs.getFloat("flutter.currentMonthExpense", 0f)
            val budget = prefs.getFloat("flutter.currentMonthBudget", 0f)

            views.setTextViewText(
                R.id.widget_title,
                "$monthLabel (${percentage.roundToInt()}%)"
            )
            views.setTextViewText(R.id.widget_subtitle, "Spent vs budget")
            views.setTextViewText(R.id.widget_expense, formatCurrency(expense))

            views.setTextViewText(
                R.id.widget_budget,
                if (budget > 0f) "of ${formatCurrency(budget)}" else "No budget"
            )

            // CLICK → OPEN APP
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

    private fun formatCurrency(value: Float): String {
        val formatter = NumberFormat.getCurrencyInstance(Locale("en", "IN"))
        formatter.maximumFractionDigits = 0
        return formatter.format(value)
    }
}
