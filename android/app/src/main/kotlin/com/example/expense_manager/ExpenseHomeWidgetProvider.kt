package com.example.expense_manager

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
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
            val expense = prefs.getAll()["currentMonthExpense"]?.toString()?.toDoubleOrNull() ?: 0.0

            views.setTextViewText(R.id.widget_expense, formatCurrency(expense))
            views.setContentDescription(
                R.id.widget_expense,
                "Current month expense ${formatCurrency(expense)}"
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

    private fun formatCurrency(value: Double): String {
        val formatter = NumberFormat.getCurrencyInstance(Locale("en", "IN"))
        formatter.maximumFractionDigits = 0
        return formatter.format(value)
    }
}
