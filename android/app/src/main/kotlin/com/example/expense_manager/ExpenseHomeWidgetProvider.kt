package com.example.expense_manager

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.NumberFormat
import java.util.Locale
import kotlin.math.roundToInt

class ExpenseHomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.expense_home_widget)

            val monthLabel = widgetData.getString("currentPeriodLabel", "Current month") ?: "Current month"
            val percentage = widgetData.getFloat("currentMonthPercentage", 0f)
            val expense = widgetData.getFloat("currentMonthExpense", 0f)
            val budget = widgetData.getFloat("currentMonthBudget", 0f)

            views.setTextViewText(
                R.id.widget_title,
                "$monthLabel (${percentage.roundToInt()}%)",
            )
            views.setTextViewText(R.id.widget_subtitle, "Spent vs budget")
            views.setTextViewText(R.id.widget_expense, formatCurrency(expense))
            views.setTextViewText(
                R.id.widget_budget,
                if (budget > 0f) "of ${formatCurrency(budget)}" else "No budget set",
            )

            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("fintrack://open?widgetId=$widgetId")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                widgetId,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )

            val addTransactionIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("fintrack://add-transaction?widgetId=$widgetId")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val addTransactionPendingIntent = PendingIntent.getActivity(
                context,
                widgetId + 10_000,
                addTransactionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )

            views.setOnClickPendingIntent(R.id.widget_container, openAppPendingIntent)
            views.setOnClickPendingIntent(
                R.id.widget_add_transaction_shortcut,
                addTransactionPendingIntent,
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun formatCurrency(value: Float): String {
        val formatter = NumberFormat.getCurrencyInstance(Locale("en", "IN"))
        formatter.maximumFractionDigits = 0
        return formatter.format(value)
    }
}
