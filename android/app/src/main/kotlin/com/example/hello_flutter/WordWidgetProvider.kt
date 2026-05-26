package com.example.hello_flutter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONArray
import kotlin.random.Random

class WordWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) {
            val appWidgetId = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
            if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                updateAppWidget(context, AppWidgetManager.getInstance(context), appWidgetId)
            }
        }
    }

    companion object {
        const val ACTION_REFRESH = "com.example.hello_flutter.WIDGET_REFRESH"
        private const val TAG = "WordWidgetProvider"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                Log.d(TAG, "updateAppWidget start, id=$appWidgetId")
                // shared_preferences plugin stores as "flutter.<key>" in FlutterSharedPreferences
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val json = prefs.getString("flutter.words_json", null)
                val allKeys = prefs.all.keys.joinToString()
                Log.d(TAG, "FlutterSharedPreferences keys=[$allKeys]")
                Log.d(TAG, "words_json length=${json?.length ?: "null"}")
                val views = RemoteViews(context.packageName, R.layout.word_widget)

                if (!json.isNullOrEmpty()) {
                    try {
                        val words = JSONArray(json)
                        if (words.length() > 0) {
                            val word = words.getJSONObject(Random.nextInt(words.length()))
                            views.setTextViewText(R.id.widget_english, word.getString("english"))
                            views.setTextViewText(R.id.widget_chinese, word.getString("chinese"))
                            views.setTextViewText(
                                R.id.widget_proficiency,
                                proficiencyEmoji(word.getInt("proficiency"))
                            )
                        } else {
                            setEmptyState(views)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "JSON parse error", e)
                        setEmptyState(views)
                    }
                } else {
                    views.setTextViewText(R.id.widget_english, "開啟 app 同步單字")
                    views.setTextViewText(R.id.widget_chinese, "")
                    views.setTextViewText(R.id.widget_proficiency, "")
                }

                // 換一個
                val refreshIntent = Intent(context, WordWidgetProvider::class.java).apply {
                    action = ACTION_REFRESH
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_refresh,
                    PendingIntent.getBroadcast(
                        context, appWidgetId, refreshIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                // 新增單字 → 帶預設單字書 ID 開 AddWordScreen
                val defaultBookId = prefs.getLong("flutter.default_word_book_id", -1L).toInt()
                Log.d(TAG, "default_word_book_id=$defaultBookId")
                val addUri = Uri.parse("wordlearner://addword?wordBookId=$defaultBookId")
                val addIntent = Intent(context, MainActivity::class.java).apply {
                    data = addUri
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                views.setOnClickPendingIntent(
                    R.id.widget_add,
                    PendingIntent.getActivity(
                        context, 1, addIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                appWidgetManager.updateAppWidget(appWidgetId, views)
                Log.d(TAG, "updateAppWidget done")
            } catch (e: Exception) {
                Log.e(TAG, "updateAppWidget FAILED", e)
            }
        }

        private fun setEmptyState(views: RemoteViews) {
            views.setTextViewText(R.id.widget_english, "還沒有單字")
            views.setTextViewText(R.id.widget_chinese, "點下方新增第一個吧")
            views.setTextViewText(R.id.widget_proficiency, "")
        }

        private fun proficiencyEmoji(proficiency: Int): String = when {
            proficiency >= 100 -> "😄"
            proficiency >= 66  -> "🙂"
            proficiency >= 33  -> "😐"
            else               -> "😢"
        }
    }
}
