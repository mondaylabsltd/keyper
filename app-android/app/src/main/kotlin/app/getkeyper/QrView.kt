package app.getkeyper

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import app.getkeyper.core.QrCode

/** Draws a QR code as a square with the standard four-module quiet zone, in whole pixels per module. */
@SuppressLint("ViewConstructor") // only ever created in code, never inflated
class QrView(context: Context, private val code: QrCode) : View(context) {
    private val dark = Paint().apply {
        color = Color.BLACK
        isAntiAlias = false
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val side = minOf(MeasureSpec.getSize(widthMeasureSpec), MeasureSpec.getSize(heightMeasureSpec))
        setMeasuredDimension(side, side)
    }

    override fun onDraw(canvas: Canvas) {
        canvas.drawColor(Color.WHITE)
        // Whole pixels everywhere, and one rectangle per horizontal run: no seams between modules.
        val unit = width / (code.size + 8)
        val origin = (width - unit * code.size) / 2
        for (y in 0 until code.size) {
            var x = 0
            while (x < code.size) {
                if (!code[x, y]) {
                    x++
                    continue
                }
                val start = x
                while (x < code.size && code[x, y]) x++
                val top = (origin + y * unit).toFloat()
                canvas.drawRect((origin + start * unit).toFloat(), top, (origin + x * unit).toFloat(), top + unit, dark)
            }
        }
    }
}
