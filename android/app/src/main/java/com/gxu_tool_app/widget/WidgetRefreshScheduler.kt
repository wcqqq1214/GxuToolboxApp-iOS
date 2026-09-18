package com.gxu_tool_app.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import com.gxu_tool_app.CourseScheduleWidgetProvider
import com.reactnativeandroidwidget.RNWidgetJsCommunication
import kotlin.math.max

private const val WIDGET_NAME = "CourseScheduleWidgetProvider"
private const val REFRESH_ACTION = "com.gxu_tool_app.widget.REFRESH_SCHEDULE"
private const val REQUEST_CODE = 1102
private const val WINDOW_MILLIS = 10 * 60 * 1000L

object WidgetRefreshScheduler {
    @JvmStatic
    fun schedule(context: Context, triggerAtMillis: Long) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val triggerAt = max(triggerAtMillis, System.currentTimeMillis() + 1000L)
        alarmManager.setWindow(
            AlarmManager.RTC,
            triggerAt,
            WINDOW_MILLIS,
            pendingIntent(context),
        )
    }

    @JvmStatic
    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        alarmManager.cancel(pendingIntent(context))
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, WidgetRefreshReceiver::class.java).setAction(REFRESH_ACTION)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

class WidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == REFRESH_ACTION) {
            RNWidgetJsCommunication.requestWidgetUpdate(context, WIDGET_NAME)
        }
    }
}

class WidgetSystemEventReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val manager = AppWidgetManager.getInstance(context)
        val provider = ComponentName(context, CourseScheduleWidgetProvider::class.java)
        if (manager.getAppWidgetIds(provider).isNotEmpty()) {
            WidgetRefreshScheduler.cancel(context)
            RNWidgetJsCommunication.requestWidgetUpdate(context, WIDGET_NAME)
        }
    }
}
