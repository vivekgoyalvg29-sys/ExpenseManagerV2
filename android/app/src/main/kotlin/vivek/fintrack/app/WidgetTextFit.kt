package vivek.fintrack.app

import android.graphics.Paint
import android.text.TextPaint
import android.util.DisplayMetrics
import android.util.TypedValue
import android.widget.RemoteViews

internal object WidgetTextFit {

    /**
     * Shrinks text size so [text] fits in [maxWidthPx] on one line (RemoteViews-safe).
     */
    fun setTextViewTextSingleLineFit(
        views: RemoteViews,
        viewId: Int,
        text: String,
        maxWidthPx: Int,
        maxSp: Float,
        minSp: Float,
        dm: DisplayMetrics,
    ) {
        views.setTextViewText(viewId, text)
        if (maxWidthPx <= 0 || text.isEmpty()) {
            views.setTextViewTextSize(
                viewId,
                TypedValue.COMPLEX_UNIT_SP,
                maxSp.coerceAtLeast(minSp),
            )
            return
        }
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG)
        var sp = maxSp
        while (sp >= minSp) {
            paint.textSize = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_SP,
                sp,
                dm,
            )
            if (paint.measureText(text) <= maxWidthPx) break
            sp -= 0.5f
        }
        views.setTextViewTextSize(viewId, TypedValue.COMPLEX_UNIT_SP, sp.coerceAtLeast(minSp))
    }
}
