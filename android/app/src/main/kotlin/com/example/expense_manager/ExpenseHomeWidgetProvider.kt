package com.example.expense_manager

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
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

            val periodLabel = widgetData.getString("currentPeriodLabel", "") ?: ""
            val budget = widgetData.getFloat("currentMonthBudget", 0f)
            val expense = widgetData.getFloat("currentMonthExpense", 0f)

            views.setTextViewText(R.id.widget_title, "Current month overview")
            views.setTextViewText(R.id.widget_period, periodLabel)
            views.setTextViewText(R.id.widget_budget, "Budget: ₹${budget.toInt()}")
            views.setTextViewText(R.id.widget_expense, "Expense: ₹${expense.toInt()}")

            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val openRecordsPendingIntent = PendingIntent.getActivity(
                context,
                widgetId,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            val openTransactionIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_records", true)
            }

            val openTransactionPendingIntent = PendingIntent.getActivity(
                context,
                widgetId + 10_000,
                openTransactionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            views.setOnClickPendingIntent(R.id.widget_container, openRecordsPendingIntent)
            views.setOnClickPendingIntent(
                R.id.widget_add_transaction_shortcut,
                openTransactionPendingIntent,
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
