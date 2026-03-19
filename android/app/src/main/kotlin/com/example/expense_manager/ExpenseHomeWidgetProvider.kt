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

            val views = RemoteViews(
                context.packageName,
                R.layout.expense_home_widget
            )

            // SAFE STATIC TEXT (no data yet)
            views.setTextViewText(R.id.widget_title, "FinTrack")
            views.setTextViewText(R.id.widget_subtitle, "Tap to open")
            views.setTextViewText(R.id.widget_expense, "₹0")
            views.setTextViewText(R.id.widget_budget, "")

            // SIMPLE CLICK → OPEN APP
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
}
