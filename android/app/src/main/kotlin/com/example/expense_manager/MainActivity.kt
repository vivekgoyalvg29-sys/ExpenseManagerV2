package com.example.expense_manager

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var navigationChannel: MethodChannel? = null
    private var pendingRoute: String? = null

    override fun getInitialRoute(): String {
        return resolveRoute(intent) ?: "/"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        navigationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )

        dispatchPendingRoute()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        pendingRoute = resolveRoute(intent)
        dispatchPendingRoute()
    }

    private fun dispatchPendingRoute() {
        val route = pendingRoute ?: return
        val channel = navigationChannel ?: return

        channel.invokeMethod("navigateToRoute", route)
        pendingRoute = null
    }

    private fun resolveRoute(intent: Intent?): String? {
        val data = intent?.data
        if (data?.scheme == "fintrack") {
            return when (data.host) {
                "add-transaction" -> "/add-transaction"
                "open-transactions" -> "/transactions"
                "open" -> "/"
                else -> "/"
            }
        }

        val openRecords = intent?.getBooleanExtra("open_records", false) ?: false
        return if (openRecords) "/transactions" else null
    }

    companion object {
        private const val CHANNEL = "fintrack/widget_navigation"
    }
}
