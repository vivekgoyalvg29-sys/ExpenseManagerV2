package com.example.expense_manager

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun getInitialRoute(): String {
        val openRecords = intent?.getBooleanExtra("open_records", false) ?: false
        return if (openRecords) "/transactions" else "/"
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
