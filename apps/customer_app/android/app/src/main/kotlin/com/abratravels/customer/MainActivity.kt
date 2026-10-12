package com.abratravels.customer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createPushChannel()
    }

    /** The channel push messages arrive on while the app is closed (Android 8 and newer). */
    private fun createPushChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            "high_priority_channel",
            "Trips and booking updates",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply { description = "Booking confirmations, trip reminders and important service alerts" }
        manager.createNotificationChannel(channel)
    }
}
