package com.example.floafinwatch

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PayoutWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val imagePath = widgetData.getString("widget_payout_img", null)
        val bitmap = if (imagePath != null) BitmapFactory.decodeFile(imagePath) else null

        appWidgetIds.forEach { widgetId ->
            val views = if (bitmap != null) {
                RemoteViews(context.packageName, R.layout.widget_payout).apply {
                    setImageViewBitmap(R.id.widget_image, bitmap)
                }
            } else {
                RemoteViews(context.packageName, R.layout.widget_payout_preview)
            }

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                android.net.Uri.parse("floafinwatch://payouts")
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        if (bitmap != null) {
            updateDynamicPreview(context, appWidgetManager, bitmap)
        }
    }

    companion object {
        private var lastPreviewTime = 0L

        fun updateDynamicPreview(context: Context, appWidgetManager: AppWidgetManager, bitmap: Bitmap) {
            val now = System.currentTimeMillis()
            if (now - lastPreviewTime < 20 * 60 * 1000L) {
                return
            }
            if (Build.VERSION.SDK_INT >= 35) {
                try {
                    val previewViews = RemoteViews(context.packageName, R.layout.widget_payout).apply {
                        setImageViewBitmap(R.id.widget_image, bitmap)
                    }
                    val method = AppWidgetManager::class.java.getMethod(
                        "setWidgetPreview",
                        ComponentName::class.java,
                        Int::class.javaPrimitiveType,
                        RemoteViews::class.java
                    )
                    val success = method.invoke(
                        appWidgetManager,
                        ComponentName(context, PayoutWidgetProvider::class.java),
                        AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN,
                        previewViews
                    )
                    if (success == true) {
                        lastPreviewTime = now
                    }
                    Log.i("PayoutWidget", "setWidgetPreview success: $success")
                } catch (e: Throwable) {
                    Log.w("PayoutWidget", "setWidgetPreview error: ${e.message}")
                }
            }
        }
    }
}
