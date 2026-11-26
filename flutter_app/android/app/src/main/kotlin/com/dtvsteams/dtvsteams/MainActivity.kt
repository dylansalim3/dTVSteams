package com.dtvsteams.dtvsteams

import android.app.Activity
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.Settings
import android.util.Rational
import android.view.WindowManager
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val PIP_CHANNEL = "com.dtvsteams.dtvsteams/pip"
    private val UPDATE_CHANNEL = "com.dtvsteams.dtvsteams/update"
    private val PLAYBACK_CHANNEL = "com.dtvsteams.dtvsteams/playback"
    private val STORAGE_CHANNEL = "com.dtvsteams.dtvsteams/storage"
    private val SHARE_CHANNEL = "com.dtvsteams.dtvsteams/share"
    private val REQUEST_CODE_PICK_DIR = 3001
    private val ACTION_PIP_CONTROL = "com.dtvsteams.dtvsteams.ACTION_PIP_CONTROL"
    private val EXTRA_CONTROL_TYPE = "control_type"
    private val CONTROL_TYPE_PLAY = 1
    private val CONTROL_TYPE_PAUSE = 2

    private var pipChannel: MethodChannel? = null
    private var updateChannel: MethodChannel? = null
    private var playbackChannel: MethodChannel? = null
    private var storageChannel: MethodChannel? = null
    private var shareChannel: MethodChannel? = null
    private var pendingDirResult: MethodChannel.Result? = null
    private var autoPipEnabled: Boolean = false
    private var pipIsPlaying: Boolean = false
    private var pipActionReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerPipActionReceiver()
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPipSupported" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val hasPip = packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                        result.success(hasPip)
                    } else {
                        result.success(false)
                    }
                }
                "enterPip" -> {
                    call.argument<Boolean>("isPlaying")?.let { pipIsPlaying = it }
                    val success = enterPipMode()
                    result.success(success)
                }
                "setAutoPip" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    autoPipEnabled = enabled
                    call.argument<Boolean>("isPlaying")?.let { pipIsPlaying = it }
                    updatePipParamsIfNeeded()
                    result.success(true)
                }
                "setPipPlaybackState" -> {
                    val playing = call.argument<Boolean>("isPlaying") ?: false
                    if (pipIsPlaying != playing) {
                        pipIsPlaying = playing
                        updatePipParamsIfNeeded()
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        updateChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
        updateChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> {
                    try {
                        val pInfo = packageManager.getPackageInfo(packageName, 0)
                        val vName = pInfo.versionName ?: "1.0.3"
                        val vCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            pInfo.versionCode.toLong()
                        }
                        result.success(mapOf(
                            "versionName" to vName,
                            "versionCode" to vCode
                        ))
                    } catch (e: Exception) {
                        result.success(mapOf(
                            "versionName" to "1.0.11",
                            "versionCode" to 12L
                        ))
                    }
                }
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (ex: Exception) {
                            result.error("SETTINGS_ERROR", ex.message, null)
                        }
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "filePath is null or empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(filePath)
                        if (!file.exists() || file.length() == 0L) {
                            result.error("FILE_NOT_FOUND", "APK file is missing or empty: $filePath", null)
                            return@setMethodCallHandler
                        }

                        // Verify the downloaded file is a valid APK and not a downgrade
                        val archiveInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageArchiveInfo(filePath, PackageManager.PackageInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageArchiveInfo(filePath, 0)
                        }
                        if (archiveInfo == null) {
                            result.error("INVALID_APK", "下載的安裝檔已損毀或格式無效，請重新下載", null)
                            return@setMethodCallHandler
                        }
                        if (archiveInfo.packageName == packageName) {
                            val currentInfo = packageManager.getPackageInfo(packageName, 0)
                            val currentCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                currentInfo.longVersionCode
                            } else {
                                @Suppress("DEPRECATION")
                                currentInfo.versionCode.toLong()
                            }
                            val apkCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                archiveInfo.longVersionCode
                            } else {
                                @Suppress("DEPRECATION")
                                archiveInfo.versionCode.toLong()
                            }
                            if (apkCode < currentCode) {
                                result.error("DOWNGRADE_BLOCKED", "安裝檔版本 ($apkCode) 低於目前安裝版本 ($currentCode)", null)
                                return@setMethodCallHandler
                            }
                        }

                        // Ensure readable permissions for external installer processes
                        file.setReadable(true, false)

                        val contentUri = FileProvider.getUriForFile(
                            this@MainActivity,
                            "$packageName.fileprovider",
                            file
                        )
                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(contentUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        // Explicitly grant URI read permissions to all matching installer components
                        val resolveInfos = packageManager.queryIntentActivities(installIntent, PackageManager.MATCH_DEFAULT_ONLY)
                        for (resolveInfo in resolveInfos) {
                            val targetPkg = resolveInfo.activityInfo.packageName
                            grantUriPermission(targetPkg, contentUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }

                        startActivity(installIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                "openBrowserUrl" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.error("INVALID_URL", "URL is null or empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BROWSER_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        playbackChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAYBACK_CHANNEL)
        playbackChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(true)
                }
                "startBackgroundPlay" -> {
                    val title = call.argument<String>("title") ?: "dTV 影音播放"
                    val part = call.argument<String>("part") ?: "背景播放中"
                    try {
                        BackgroundAudioService.pendingStop = false
                        BackgroundAudioService.pendingStarts.incrementAndGet()
                        val serviceIntent = Intent(this, BackgroundAudioService::class.java).apply {
                            action = BackgroundAudioService.ACTION_START
                            putExtra(BackgroundAudioService.EXTRA_TITLE, title)
                            putExtra(BackgroundAudioService.EXTRA_PART, part)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        BackgroundAudioService.pendingStarts.updateAndGet { cur -> if (cur > 0) cur - 1 else 0 }
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopBackgroundPlay" -> {
                    try {
                        BackgroundAudioService.pendingStop = true
                        // Only call stopService immediately once no startForegroundService() is in flight;
                        // otherwise onStartCommand will call startForeground() first and stop itself safely.
                        if (BackgroundAudioService.isRunning && BackgroundAudioService.pendingStarts.get() <= 0) {
                            BackgroundAudioService.pendingStop = false
                            stopService(Intent(this, BackgroundAudioService::class.java))
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "setScreenBrightness" -> {
                    val brightness = call.argument<Double>("brightness") ?: -1.0
                    runOnUiThread {
                        val lp = window.attributes
                        lp.screenBrightness = if (brightness < 0) -1.0f else brightness.toFloat().coerceIn(0.01f, 1.0f)
                        window.attributes = lp
                    }
                    result.success(true)
                }
                "getScreenBrightness" -> {
                    val b = window.attributes.screenBrightness.toDouble()
                    result.success(if (b < 0) 0.5 else b)
                }
                else -> result.notImplemented()
            }
        }

        storageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL)
        storageChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(Environment.isExternalStorageManager())
                    } else {
                        val granted = checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    }
                }
                "requestStoragePermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            requestPermissions(arrayOf(
                                android.Manifest.permission.WRITE_EXTERNAL_STORAGE,
                                android.Manifest.permission.READ_EXTERNAL_STORAGE
                            ), 2001)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (ex: Exception) {
                            result.error("PERMISSION_ERROR", ex.message, null)
                        }
                    }
                }
                "getPublicStorageLocations" -> {
                    val locations = mutableMapOf<String, String>()
                    try {
                        val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                        if (downloads != null) {
                            locations["downloads"] = File(downloads, "dTVSteams").absolutePath
                        }
                    } catch (_: Exception) {}
                    try {
                        val movies = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
                        if (movies != null) {
                            locations["movies"] = File(movies, "dTVSteams").absolutePath
                        }
                    } catch (_: Exception) {}
                    try {
                        val extApp = getExternalFilesDir(null)
                        if (extApp != null) {
                            locations["appExternal"] = File(extApp, "Downloads").absolutePath
                        }
                    } catch (_: Exception) {}
                    result.success(locations)
                }
                "pickDirectory" -> {
                    try {
                        pendingDirResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        }
                        startActivityForResult(intent, REQUEST_CODE_PICK_DIR)
                    } catch (e: Exception) {
                        pendingDirResult = null
                        result.error("PICK_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
        shareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "shareText" -> {
                    val text = call.argument<String>("text")
                    val title = call.argument<String>("title") ?: "分享連結"
                    if (text.isNullOrEmpty()) {
                        result.error("INVALID_TEXT", "text is null or empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                            putExtra(Intent.EXTRA_SUBJECT, title)
                        }
                        val chooser = Intent.createChooser(shareIntent, title).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }
                "shareFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val title = call.argument<String>("title") ?: "分享影片"
                    val mimeType = call.argument<String>("mimeType") ?: "video/mp4"
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "filePath is null or empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                            return@setMethodCallHandler
                        }
                        val contentUri = FileProvider.getUriForFile(
                            this@MainActivity,
                            "$packageName.fileprovider",
                            file
                        )
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = mimeType
                            putExtra(Intent.EXTRA_STREAM, contentUri)
                            putExtra(Intent.EXTRA_SUBJECT, title)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        val chooser = Intent.createChooser(shareIntent, title).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }
                "shareFiles" -> {
                    val filePaths = call.argument<List<String>>("filePaths")
                    val title = call.argument<String>("title") ?: "分享影片"
                    val mimeType = call.argument<String>("mimeType") ?: "video/mp4"
                    if (filePaths.isNullOrEmpty()) {
                        result.error("INVALID_PATHS", "filePaths is empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uris = ArrayList<Uri>()
                        for (path in filePaths) {
                            val file = File(path)
                            if (file.exists()) {
                                val uri = FileProvider.getUriForFile(
                                    this@MainActivity,
                                    "$packageName.fileprovider",
                                    file
                                )
                                uris.add(uri)
                            }
                        }
                        if (uris.isEmpty()) {
                            result.error("FILES_NOT_FOUND", "None of the files exist", null)
                            return@setMethodCallHandler
                        }
                        val shareIntent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                            type = mimeType
                            putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                            putExtra(Intent.EXTRA_SUBJECT, title)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        val chooser = Intent.createChooser(shareIntent, title).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_DIR) {
            val res = pendingDirResult
            pendingDirResult = null
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data
                try {
                    contentResolver.takePersistableUriPermission(
                        uri!!,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                } catch (_: Exception) {}
                val resolvedPath = getPathFromTreeUri(uri)
                res?.success(resolvedPath)
            } else {
                res?.success(null)
            }
        }
    }

    private fun getPathFromTreeUri(uri: Uri?): String? {
        if (uri == null) return null
        try {
            val docId = DocumentsContract.getTreeDocumentId(uri)
            if (docId != null) {
                val parts = docId.split(":")
                val type = parts[0]
                val relativePath = if (parts.size > 1) parts[1] else ""
                if ("primary".equals(type, ignoreCase = true)) {
                    val base = Environment.getExternalStorageDirectory().absolutePath
                    return if (relativePath.isNotEmpty()) "$base/$relativePath" else base
                } else {
                    val externalDirs = getExternalFilesDirs(null)
                    for (f in externalDirs) {
                        if (f != null) {
                            val path = f.absolutePath
                            val index = path.indexOf("/Android/data/")
                            if (index > 0) {
                                val root = path.substring(0, index)
                                if (root.contains(type)) {
                                    return if (relativePath.isNotEmpty()) "$root/$relativePath" else root
                                }
                            }
                        }
                    }
                    return "/storage/$type/$relativePath"
                }
            }
        } catch (_: Exception) {}
        return uri.path
    }

    private fun registerPipActionReceiver() {
        unregisterPipActionReceiver()
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != ACTION_PIP_CONTROL) return
                val controlType = intent.getIntExtra(EXTRA_CONTROL_TYPE, 0)
                val actionName = when (controlType) {
                    CONTROL_TYPE_PAUSE -> "pause"
                    CONTROL_TYPE_PLAY -> "play"
                    else -> "togglePlayPause"
                }
                pipChannel?.invokeMethod("onPipAction", actionName)
            }
        }
        ContextCompat.registerReceiver(
            this,
            receiver,
            IntentFilter(ACTION_PIP_CONTROL),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        pipActionReceiver = receiver
    }

    private fun unregisterPipActionReceiver() {
        try {
            pipActionReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        pipActionReceiver = null
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun buildPlayPauseRemoteAction(isPlaying: Boolean): RemoteAction {
        val controlType = if (isPlaying) CONTROL_TYPE_PAUSE else CONTROL_TYPE_PLAY
        val iconRes = if (isPlaying) {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        val title = if (isPlaying) "暫停" else "播放"
        val intent = Intent(ACTION_PIP_CONTROL).apply {
            setPackage(packageName)
            putExtra(EXTRA_CONTROL_TYPE, controlType)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getBroadcast(this, controlType, intent, flags)
        return RemoteAction(
            Icon.createWithResource(this, iconRes),
            title,
            title,
            pendingIntent
        )
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun buildPipParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .setActions(listOf(buildPlayPauseRemoteAction(pipIsPlaying)))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoPipEnabled)
        }
        return builder.build()
    }

    private fun updatePipParamsIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val shouldUpdate = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            isInPictureInPictureMode || autoPipEnabled
        } else {
            isInPictureInPictureMode
        }
        if (shouldUpdate) {
            try {
                setPictureInPictureParams(buildPipParams())
            } catch (_: Exception) {}
        }
    }

    private fun enterPipMode(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                return enterPictureInPictureMode(buildPipParams())
            } catch (e: Exception) {
                return false
            }
        }
        return false
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (autoPipEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            enterPipMode()
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) {
            updatePipParamsIfNeeded()
        }
        pipChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    override fun onDestroy() {
        unregisterPipActionReceiver()
        try {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val serviceIntent = Intent(this, BackgroundAudioService::class.java).apply {
                action = BackgroundAudioService.ACTION_STOP
            }
            startService(serviceIntent)
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
