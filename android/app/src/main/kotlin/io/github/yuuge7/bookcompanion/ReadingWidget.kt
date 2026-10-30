package io.github.yuuge7.bookcompanion

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class ReadingWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        render(context, manager, ids)
    }
    companion object {
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            render(context, manager, manager.getAppWidgetIds(ComponentName(context, ReadingWidget::class.java)))
        }
        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences("device", Context.MODE_PRIVATE)
            val locked = prefs.getBoolean("private", false)
            val title = if (locked) "Library locked" else prefs.getString("title", "No book open")
            val bookId = if (locked) "" else prefs.getString("id", "")
            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.reading_widget)
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_progress, if (locked) "Tap to unlock" else prefs.getString("progress", "Start reading in Book Companion"))
                views.setProgressBar(R.id.widget_bar, 100, if (locked) 0 else prefs.getInt("percent", 0), false)
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("bookId", bookId)
                }
                val pending = PendingIntent.getActivity(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.widget_root, pending)
                manager.updateAppWidget(id, views)
            }
        }
    }
}
