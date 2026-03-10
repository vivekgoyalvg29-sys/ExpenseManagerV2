package com.example.expense_manager

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ExpenseHomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.expense_home_widget)

            val title = widgetData.getString("title", "Budget vs Expense") ?: "Budget vs Expense"
            val modeLabel = widgetData.getString("modeLabel", "Selected month") ?: "Selected month"
            val periodLabel = widgetData.getString("periodLabel", "") ?: ""
            val budget = widgetData.getFloat("budget", 0f)
            val expense = widgetData.getFloat("expense", 0f)
            val remaining = widgetData.getFloat("remaining", 0f)

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_mode, modeLabel)
            views.setTextViewText(R.id.widget_period, periodLabel)
            views.setTextViewText(R.id.widget_budget, "Budget: ₹${budget.toInt()}")
            views.setTextViewText(R.id.widget_expense, "Expense: ₹${expense.toInt()}")
            views.setTextViewText(R.id.widget_remaining, "Remaining: ₹${remaining.toInt()}")

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
