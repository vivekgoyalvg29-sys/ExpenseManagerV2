package com.example.expense_manager

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var navigationChannel: MethodChannel? = null
    private var pendingRoute: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 🔥 Do NOT navigate here — just store intent
        pendingRoute = resolveRoute(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        navigationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        // 🔥 Delay navigation to ensure Flutter is ready
        mainHandler.postDelayed({
            dispatchPendingRoute()
        }, 500)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        pendingRoute = resolveRoute(intent)

        // 🔥 Safe dispatch
        mainHandler.postDelayed({
            dispatchPendingRoute()
        }, 300)
    }

    private fun dispatchPendingRoute() {
        val route = pendingRoute ?: return
        val channel = navigationChannel ?: return

        try {
            channel.invokeMethod("navigateToRoute", route)
            pendingRoute = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
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
