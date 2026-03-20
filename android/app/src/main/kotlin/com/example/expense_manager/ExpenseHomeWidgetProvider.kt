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

            val expense = prefs.getAll()["currentMonthExpense"]?.toString()?.toDoubleOrNull() ?: 0.0
            val budget = prefs.getAll()["currentMonthBudget"]?.toString()?.toDoubleOrNull() ?: 0.0
            val periodLabel = prefs.getString("currentPeriodLabel", "Month") ?: "Month"

            val monthLabel = try {
                val now = java.util.Calendar.getInstance()
                val year = now.get(java.util.Calendar.YEAR).toString().takeLast(2)
                "$periodLabel-$year"
            } catch (e: Exception) {
                periodLabel
            }

            val percentage = if (budget > 0.0) ((expense / budget) * 100).roundToInt() else 0

            views.setTextViewText(R.id.widget_month, monthLabel)
            views.setTextViewText(R.id.widget_expense, formatCurrency(expense))
            views.setTextViewText(R.id.widget_percentage, "($percentage%)")

            // Tap container → open app home
            val openIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openPendingIntent = PendingIntent.getActivity(
                context, widgetId, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, openPendingIntent)

            // Tap arrow → open Add Transaction via deep link
            val addIntent = Intent(Intent.ACTION_VIEW).apply {
                data = android.net.Uri.parse("fintrack://add-transaction")
                setPackage(context.packageName)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val addPendingIntent = PendingIntent.getActivity(
                context, widgetId + 1000, addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_add, addPendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun formatCurrency(value: Double): String {
        val formatter = NumberFormat.getCurrencyInstance(Locale("en", "IN"))
        formatter.maximumFractionDigits = 0
        return formatter.format(value)
    }
}
