package com.dtvsteams.dtvsteams

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import java.util.concurrent.atomic.AtomicInteger

class BackgroundAudioService : Service() {
    companion object {
        const val CHANNEL_ID = "dtv_background_audio"
        const val NOTIFICATION_ID = 8801
        const val ACTION_START = "com.dtvsteams.dtvsteams.START_BACKGROUND_AUDIO"
        const val ACTION_STOP = "com.dtvsteams.dtvsteams.STOP_BACKGROUND_AUDIO"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_PART = "extra_part"

        @Volatile
        var isRunning = false
            private set

        @Volatile
        var pendingStop = false

        val pendingStarts = AtomicInteger(0)
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "dTV 影音播放"
        val part = intent?.getStringExtra(EXTRA_PART) ?: "背景播放中"

        // Always call startForeground() first to satisfy every queued startForegroundService()
        // promise before stopping, preventing ForegroundServiceDidNotStartInTimeException.
        startForegroundNotification(title, part)

        if (intent?.action != ACTION_STOP) {
            pendingStarts.updateAndGet { cur -> if (cur > 0) cur - 1 else 0 }
        }

        if (intent?.action == ACTION_STOP || (pendingStop && pendingStarts.get() <= 0)) {
            pendingStop = false
            pendingStarts.set(0)
            stopBackgroundAudio()
            return START_NOT_STICKY
        }

        acquireWakeLock()
        isRunning = true
        return START_NOT_STICKY
    }

    private fun startForegroundNotification(title: String, part: String) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            this.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder.setContentTitle(title)
            .setContentText("$part • 正在背景/鎖定螢幕播放音訊")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            builder.setVisibility(Notification.VISIBILITY_PUBLIC)
        }

        val notification = builder.build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "dtvsteams:BackgroundAudioWakeLock")
                wakeLock?.setReferenceCounted(false)
            }
            if (wakeLock?.isHeld != true) {
                wakeLock?.acquire(3 * 60 * 60 * 1000L) // 3 hours safety timeout
            }
        } catch (_: Exception) {}
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
    }

    private fun stopBackgroundAudio() {
        releaseWakeLock()
        isRunning = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        stopBackgroundAudio()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "背景音訊播放 (Background Playback)",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "鎖定螢幕或切換應用時保持背景音訊持續播放"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
}
