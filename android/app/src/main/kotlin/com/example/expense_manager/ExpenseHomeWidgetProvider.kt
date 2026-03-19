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

            val views = RemoteViews(
                context.packageName,
                android.R.layout.simple_list_item_1
            )

            views.setTextViewText(
                android.R.id.text1,
                "Widget Loaded"
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
