package vivek.fintrack.app

import android.content.SharedPreferences
import java.text.NumberFormat
import java.util.Locale

internal object HomeWidgetPreferences {

    fun periodTitle(prefs: SharedPreferences): String =
        readString(prefs, "widget_card_period_title", "—")

    fun expenseDisplay(prefs: SharedPreferences): String =
        readString(prefs, "widget_expense_display", formatCurrency(readExpenseForDisplay(prefs)))

    fun calendarDay(prefs: SharedPreferences): Int =
        readInt(prefs, "widget_calendar_day", 1).coerceIn(1, 31)

    fun paceVisible(prefs: SharedPreferences): Boolean =
        readInt(prefs, "widget_pace_visible", 0) == 1

    fun paceLabel(prefs: SharedPreferences): String =
        readString(prefs, "widget_pace_label", "")

    fun paceIsHigh(prefs: SharedPreferences): Boolean =
        readInt(prefs, "widget_pace_is_high", 0) == 1

    fun barProgressThousandths(prefs: SharedPreferences): Int =
        readInt(prefs, "widget_bar_progress_thousandths", 0).coerceIn(0, 1000)

    fun gaugeProgressThousandths(prefs: SharedPreferences, barFallback: Int): Int =
        readInt(prefs, "widget_gauge_progress_thousandths", barFallback).coerceIn(0, 1000)

    fun modeShort(prefs: SharedPreferences): String =
        readString(prefs, "widget_mode_short", "")

    private fun readExpenseForDisplay(prefs: SharedPreferences): Double =
        readDouble(prefs, "expense", 0.0)

    private fun readDouble(prefs: SharedPreferences, key: String, default: Double): Double {
        if (!prefs.contains(key)) return default
        val isDoubleBits = prefs.getBoolean("home_widget.double.$key", false)
        val raw = prefs.all[key] ?: return default
        if (isDoubleBits && raw is Long) {
            return java.lang.Double.longBitsToDouble(raw)
        }
        return when (raw) {
            is Double -> raw
            is Float -> raw.toDouble()
            is Int -> raw.toDouble()
            is Long -> if (isDoubleBits) java.lang.Double.longBitsToDouble(raw) else raw.toDouble()
            is String -> raw.toDoubleOrNull() ?: default
            else -> default
        }
    }

    private fun readInt(prefs: SharedPreferences, key: String, default: Int): Int {
        val raw = prefs.all[key] ?: return default
        return when (raw) {
            is Int -> raw
            is Long -> raw.toInt()
            is String -> raw.toIntOrNull() ?: default
            else -> default
        }
    }

    private fun readString(prefs: SharedPreferences, key: String, default: String): String {
        prefs.getString(key, null)?.let { return it }
        return (prefs.all[key] as? String) ?: default
    }

    private fun formatCurrency(value: Double): String {
        val formatter = NumberFormat.getCurrencyInstance(Locale("en", "IN"))
        formatter.maximumFractionDigits = 0
        return formatter.format(value)
    }
}
