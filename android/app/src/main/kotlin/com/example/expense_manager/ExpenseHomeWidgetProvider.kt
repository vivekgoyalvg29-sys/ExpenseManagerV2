package com.example.expense_manager

import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ExpenseHomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, views: RemoteViews, widgetId: Int) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        val title = prefs.getString("title", "Budget vs Expense") ?: "Budget vs Expense"
        val modeLabel = prefs.getString("modeLabel", "Selected month") ?: "Selected month"
        val periodLabel = prefs.getString("periodLabel", "") ?: ""
        val budget = prefs.getFloat("budget", 0f)
        val expense = prefs.getFloat("expense", 0f)
        val remaining = prefs.getFloat("remaining", 0f)

        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_mode, modeLabel)
        views.setTextViewText(R.id.widget_period, periodLabel)
        views.setTextViewText(R.id.widget_budget, "Budget: ₹${budget.toInt()}")
        views.setTextViewText(R.id.widget_expense, "Expense: ₹${expense.toInt()}")
        views.setTextViewText(R.id.widget_remaining, "Remaining: ₹${remaining.toInt()}")
    }
}
