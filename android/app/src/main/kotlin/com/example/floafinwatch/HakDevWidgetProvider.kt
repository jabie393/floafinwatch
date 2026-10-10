package com.example.floafinwatch

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HakDevWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val imagePath = widgetData.getString("widget_hak_dev_img", null)
        val bitmap = if (imagePath != null) BitmapFactory.decodeFile(imagePath) else null

        val themeMode = widgetData.getString("theme_mode", "system") ?: "system"
        val isSystemDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        val shouldBeDark = when (themeMode) {
            "dark" -> true
            "light" -> false
            else -> isSystemDark
        }
        val fallbackLayout = if (shouldBeDark) R.layout.widget_hak_dev_preview_dark else R.layout.widget_hak_dev_preview_light

        appWidgetIds.forEach { widgetId ->
            val views = if (bitmap != null) {
                RemoteViews(context.packageName, R.layout.widget_hak_dev).apply {
                    setImageViewBitmap(R.id.widget_image, bitmap)
                }
            } else {
                RemoteViews(context.packageName, fallbackLayout)
            }

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                android.net.Uri.parse("floafinwatch://dashboard")
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        updateDynamicPreview(context, appWidgetManager, widgetData)
    }

    companion object {
        private var lastPreviewTime = 0L
        private var lastPreviewHash = ""

        fun updateDynamicPreview(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetData: SharedPreferences,
            force: Boolean = false
        ) {
            val amount = widgetData.getString("hak_dev_amount_str", "Rp 0") ?: "Rp 0"
            val cair = widgetData.getString("hak_dev_cair_str", "Rp 0 cair") ?: "Rp 0 cair"

            val themeMode = widgetData.getString("theme_mode", "system") ?: "system"
            val isSystemDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
            val shouldBeDark = when (themeMode) {
                "dark" -> true
                "light" -> false
                else -> isSystemDark
            }

            val contentHash = "$themeMode|$isSystemDark|$shouldBeDark|$amount|$cair"
            val now = System.currentTimeMillis()
            if (!force && contentHash == lastPreviewHash && (now - lastPreviewTime < 25 * 60 * 1000L)) {
                return
            }

            if (Build.VERSION.SDK_INT >= 35) {
                try {
                    // Preview di Widget Picker sistem launcher selalu default Light Mode
                    val previewLayout = R.layout.widget_hak_dev_preview_light
                    val previewViews = RemoteViews(context.packageName, previewLayout).apply {
                        setTextViewText(R.id.preview_hak_dev_amount, amount)
                        setTextViewText(R.id.preview_hak_dev_cair, cair)
                    }
                    val method = AppWidgetManager::class.java.getMethod(
                        "setWidgetPreview",
                        ComponentName::class.java,
                        Int::class.javaPrimitiveType,
                        RemoteViews::class.java
                    )
                    val success = method.invoke(
                        appWidgetManager,
                        ComponentName(context, HakDevWidgetProvider::class.java),
                        AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN,
                        previewViews
                    )
                    if (success == true) {
                        lastPreviewTime = now
                        lastPreviewHash = contentHash
                    }
                    Log.i("HakDevWidget", "setWidgetPreview success: $success, hash=$contentHash, dark=$shouldBeDark")
                } catch (e: Throwable) {
                    Log.w("HakDevWidget", "setWidgetPreview error: ${e.message}")
                }
            }
        }
    }
}
