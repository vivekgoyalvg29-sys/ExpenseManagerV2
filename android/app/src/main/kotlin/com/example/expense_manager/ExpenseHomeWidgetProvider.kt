package com.example.expense_manager

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.widget.RemoteViews
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
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
            val expense = prefs.getNumericValue("currentMonthExpense")
            val monthLabel = prefs.getString("currentMonthWidgetLabel", null)
                ?: SimpleDateFormat("MMMM-yy", Locale.ENGLISH).format(Date())

            views.setTextViewText(R.id.widget_month_label, monthLabel)
            views.setTextViewText(R.id.widget_expense, formatCurrency(expense))
            views.setContentDescription(
                R.id.widget_expense_section,
                "$monthLabel expense ${formatCurrency(expense)}"
            )

            views.setOnClickPendingIntent(
                R.id.widget_container,
                createLaunchPendingIntent(context, widgetId, null)
            )
            views.setOnClickPendingIntent(
                R.id.widget_add_transaction_shortcut,
                createLaunchPendingIntent(context, widgetId + 10_000, "/add-transaction")
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun createLaunchPendingIntent(
        context: Context,
        requestCode: Int,
        route: String?
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            route?.let { putExtra(MainActivity.EXTRA_WIDGET_ROUTE, it) }
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        return PendingIntent.getActivity(context, requestCode, intent, flags)
    }

    private fun SharedPreferences.getNumericValue(key: String): Double {
        return when (val value = all[key]) {
            is Double -> value
            is Float -> value.toDouble()
            is Long -> value.toDouble()
            is Int -> value.toDouble()
            is String -> value.toDoubleOrNull() ?: 0.0
            is Number -> value.toDouble()
            else -> 0.0
        }
    }

    private fun formatCurrency(value: Double): String {
        val formatter = NumberFormat.getCurrencyInstance(Locale("en", "IN"))
        formatter.maximumFractionDigits = 0
        return formatter.format(value)
    }
}
