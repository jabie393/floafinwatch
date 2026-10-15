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

class TrendChartWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        try {
            val imagePath = widgetData.getString("widget_trend_img", null)
            val bitmap = if (imagePath != null) BitmapFactory.decodeFile(imagePath) else null

            val themeMode = widgetData.getString("theme_mode", "system") ?: "system"
            val isSystemDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
            val shouldBeDark = when (themeMode) {
                "dark" -> true
                "light" -> false
                else -> isSystemDark
            }
            val fallbackLayout = if (shouldBeDark) R.layout.widget_trend_preview_dark else R.layout.widget_trend_preview_light

            appWidgetIds.forEach { widgetId ->
                val views = if (bitmap != null) {
                    RemoteViews(context.packageName, R.layout.widget_trend).apply {
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
        } catch (e: Throwable) {
            Log.e("TrendChartWidget", "Error during onUpdate: ${e.message}", e)
        }
    }

    companion object {
        private var lastPreviewTime = 0L
        private var lastPreviewHash = ""

        private fun getSafeFloat(widgetData: SharedPreferences, key: String, defaultVal: Float): Float {
            return try {
                val value = widgetData.all[key] ?: return defaultVal
                when (value) {
                    is Float -> value
                    is Double -> value.toFloat()
                    is Long -> {
                        val asDouble = java.lang.Double.longBitsToDouble(value)
                        if (asDouble in 0.0..1000.0 && !asDouble.isNaN()) asDouble.toFloat() else value.toFloat()
                    }
                    is Number -> value.toFloat()
                    is String -> value.toFloatOrNull() ?: defaultVal
                    else -> defaultVal
                }
            } catch (_: Throwable) {
                defaultVal
            }
        }

        fun updateDynamicPreview(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetData: SharedPreferences,
            force: Boolean = false
        ) {
            try {
                val badge = widgetData.getString("trend_badge_str", "+12%") ?: "+12%"
                val max = widgetData.getString("trend_max_str", "Rp 345 rb") ?: "Rp 345 rb"
                val mid = widgetData.getString("trend_mid_str", "Rp 172 rb") ?: "Rp 172 rb"
                val startDate = widgetData.getString("trend_date_start_str", "04 OCT") ?: "04 OCT"
                val endDate = widgetData.getString("trend_date_end_str", "10 OCT") ?: "10 OCT"

                val themeMode = widgetData.getString("theme_mode", "system") ?: "system"
                val isSystemDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
                val shouldBeDark = when (themeMode) {
                    "dark" -> true
                    "light" -> false
                    else -> isSystemDark
                }

                val pillarsHash = (1..7).joinToString(",") { getSafeFloat(widgetData, "trend_pillar_${it}_height", 0f).toString() }
                val contentHash = "$themeMode|$isSystemDark|$shouldBeDark|$badge|$max|$mid|$startDate|$endDate|$pillarsHash"
                val now = System.currentTimeMillis()
                if (!force && contentHash == lastPreviewHash && (now - lastPreviewTime < 25 * 60 * 1000L)) {
                    return
                }

                if (Build.VERSION.SDK_INT >= 35) {
                    try {
                        // Preview di Widget Picker sistem launcher selalu default Light Mode
                        val previewLayout = R.layout.widget_trend_preview_light
                        val pillarLightRes = R.drawable.pillar_light
                        val pillarPeakRes = R.drawable.pillar_peak

                        val previewViews = RemoteViews(context.packageName, previewLayout).apply {
                            setTextViewText(R.id.trend_badge, badge)
                            setTextViewText(R.id.trend_max_label, max)
                            setTextViewText(R.id.trend_mid_label, mid)
                            setTextViewText(R.id.trend_date_start, startDate)
                            setTextViewText(R.id.trend_date_end, endDate)

                            val pillarIds = intArrayOf(
                                R.id.pillar_1, R.id.pillar_2, R.id.pillar_3, R.id.pillar_4,
                                R.id.pillar_5, R.id.pillar_6, R.id.pillar_7
                            )
                            val defaultHeights = floatArrayOf(22f, 22f, 36f, 30f, 60f, 34f, 22f)
                            for (i in 0 until 7) {
                                val rawH = getSafeFloat(widgetData, "trend_pillar_${i + 1}_height", defaultHeights[i])
                                val h = rawH.coerceIn(22f, 56f)
                                val isPeak = try {
                                    val peakVal = widgetData.all["trend_pillar_${i + 1}_is_peak"]
                                    if (peakVal is Boolean) peakVal else (i == 4)
                                } catch (_: Throwable) { i == 4 }

                                setViewLayoutHeight(pillarIds[i], h, android.util.TypedValue.COMPLEX_UNIT_DIP)
                                setInt(pillarIds[i], "setBackgroundResource", if (isPeak) pillarPeakRes else pillarLightRes)
                            }
                        }
                        val method = AppWidgetManager::class.java.getMethod(
                            "setWidgetPreview",
                            ComponentName::class.java,
                            Int::class.javaPrimitiveType,
                            RemoteViews::class.java
                        )
                        val success = method.invoke(
                            appWidgetManager,
                            ComponentName(context, TrendChartWidgetProvider::class.java),
                            AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN,
                            previewViews
                        )
                        if (success == true) {
                            lastPreviewTime = now
                            lastPreviewHash = contentHash
                        }
                        Log.i("TrendChartWidget", "setWidgetPreview success: $success, hash=$contentHash, dark=$shouldBeDark")
                    } catch (e: Throwable) {
                        Log.w("TrendChartWidget", "setWidgetPreview error: ${e.message}")
                    }
                }
            } catch (e: Throwable) {
                Log.e("TrendChartWidget", "Error during updateDynamicPreview: ${e.message}", e)
            }
        }
    }
}
