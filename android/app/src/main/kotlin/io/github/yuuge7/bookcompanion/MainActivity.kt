package io.github.yuuge7.bookcompanion

import android.content.Intent
import android.content.ComponentName
import android.appwidget.AppWidgetManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    override fun onCreate(savedInstanceState: Bundle?) {
        if (getSharedPreferences("device", MODE_PRIVATE).getBoolean("secure", false)) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        super.onCreate(savedInstanceState)
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "book_companion/device")
        channel!!.setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("device", MODE_PRIVATE)
            when (call.method) {
                "pinWidget" -> {
                    val manager = AppWidgetManager.getInstance(this)
                    result.success(Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported &&
                        manager.requestPinAppWidget(ComponentName(this, ReadingWidget::class.java), null, null))
                }
                "appLockEnabled" -> result.success(prefs.getBoolean("private", false))
                "securePreviewEnabled" -> result.success((window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0)
                "securePreview" -> {
                    val secure = call.arguments == true
                    prefs.edit().putBoolean("secure", secure).apply()
                    if (secure) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "widgetPrivacy" -> {
                    prefs.edit().putBoolean("private", call.arguments == true).apply()
                    ReadingWidget.refresh(this)
                    result.success(null)
                }
                "updateWidget" -> {
                    val editor = prefs.edit()
                    for (key in listOf("id", "title", "progress")) {
                        editor.putString(key, call.argument<String>(key) ?: "")
                    }
                    editor.putInt("percent", call.argument<Int>("percent") ?: 0).apply()
                    ReadingWidget.refresh(this)
                    result.success(null)
                }
                "initialBook" -> {
                    result.success(intent.getStringExtra("bookId"))
                    intent.removeExtra("bookId")
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        channel?.invokeMethod("openBook", intent.getStringExtra("bookId"))
        intent.removeExtra("bookId")
    }
}
