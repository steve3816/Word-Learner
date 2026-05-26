package com.example.hello_flutter

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.hello_flutter/widget"
    private var pendingWidgetUri: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialUri" -> {
                        result.success(pendingWidgetUri)
                        pendingWidgetUri = null
                    }
                    else -> result.notImplemented()
                }
            }
        // App cold-started from widget click
        pendingWidgetUri = intent?.data?.toString()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val uri = intent.data?.toString() ?: return
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, channelName).invokeMethod("onWidgetUri", uri)
        }
    }
}
