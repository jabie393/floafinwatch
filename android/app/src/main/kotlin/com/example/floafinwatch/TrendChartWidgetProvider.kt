package com.example.floafinwatch

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class TrendChartWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val imagePath = widgetData.getString("widget_trend_img", null)
            val bitmap = if (imagePath != null) BitmapFactory.decodeFile(imagePath) else null

            val views = if (bitmap != null) {
                RemoteViews(context.packageName, R.layout.widget_trend).apply {
                    setImageViewBitmap(R.id.widget_image, bitmap)
                }
            } else {
                RemoteViews(context.packageName, R.layout.widget_trend_preview)
            }

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
