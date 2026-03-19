package com.example.expense_manager

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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

            val openAppPendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("fintrack://open?widgetId=$widgetId"),
            )

            val addTransactionPendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("fintrack://add-transaction?widgetId=$widgetId"),
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
