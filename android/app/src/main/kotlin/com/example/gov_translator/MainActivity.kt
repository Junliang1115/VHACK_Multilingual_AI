package com.example.gov_translator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.content.Intent

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.gov_translator/app_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "moveToBackground") {
                val moved = moveTaskToBack(true)
                result.success(moved)
            } else if (call.method == "bringToForeground") {
                val intent = Intent(this@MainActivity, MainActivity::class.java)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                startActivity(intent)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
