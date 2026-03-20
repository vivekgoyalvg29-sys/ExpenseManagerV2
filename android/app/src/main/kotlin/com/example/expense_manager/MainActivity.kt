package com.example.expense_manager

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "fintrack/widget_navigation"
        const val EXTRA_WIDGET_ROUTE = "widget_route"
    }

    private var navigationChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        navigationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        dispatchWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchWidgetIntent(intent)
    }

    private fun dispatchWidgetIntent(intent: Intent?) {
        val route = intent?.getStringExtra(EXTRA_WIDGET_ROUTE) ?: return
        navigationChannel?.invokeMethod("navigateToRoute", route)
        intent.removeExtra(EXTRA_WIDGET_ROUTE)
    }
}
