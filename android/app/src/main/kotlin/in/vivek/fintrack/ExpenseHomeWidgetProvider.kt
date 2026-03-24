package com.example.expense_manager

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Locale

class ExpenseHomeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.expense_home_widget)

            val expenseRaw = prefs.getAll()["currentMonthExpense"]
            val expense = when (expenseRaw) {
                is Double -> expenseRaw
                is Float -> expenseRaw.toDouble()
                is Long -> java.lang.Double.longBitsToDouble(expenseRaw)
                is Int -> expenseRaw.toDouble()
                is String -> expenseRaw.toDoubleOrNull() ?: 0.0
                else -> 0.0
            }

            val periodLabel = prefs.getString("currentPeriodLabel", "Month") ?: "Month"
            val monthLabel = try {
                val now = java.util.Calendar.getInstance()
                val year = now.get(java.util.Calendar.YEAR).toString().takeLast(2)
                "$periodLabel-$year"
            } catch (e: Exception) {
                periodLabel
            }

            views.setTextViewText(R.id.widget_month, monthLabel)
            views.setTextViewText(R.id.widget_expense, formatCurrency(expense))

            // Tap → open app
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, widgetId, intent,
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
