package com.dtvsteams.ui

import android.content.Context
import androidx.annotation.OptIn
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import androidx.tv.material3.Button
import androidx.tv.material3.ButtonDefaults
import androidx.tv.material3.Text
import com.dtvsteams.catalog.Episode
import com.dtvsteams.catalog.Part

@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(
    episode: Episode,
    initialPartIndex: Int = 0,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    var currentPartIndex by remember { mutableStateOf(initialPartIndex) }
    var playbackError by remember { mutableStateOf<String?>(null) }
    var isOsdVisible by remember { mutableStateOf(true) }

    val parts = if (episode.parts.isNotEmpty()) episode.parts else listOf(
        Part("Part 1", episode.url),
        Part("Part 2", "${episode.url}2/"),
        Part("Part 3", "${episode.url}3/")
    )

    val currentPart = parts.getOrElse(currentPartIndex) { parts[0] }

    val exoPlayer = remember {
        ExoPlayer.Builder(context).build().apply {
            playWhenReady = true
        }
    }

    DisposableEffect(currentPart) {
        val prefs = context.getSharedPreferences("dtv_tv_resume", Context.MODE_PRIVATE)
        val savedMs = prefs.getLong("resume_${episode.id}_${currentPartIndex}", 0L)

        val mediaItem = MediaItem.fromUri(currentPart.url)
        exoPlayer.setMediaItem(mediaItem)
        exoPlayer.prepare()
        if (savedMs > 5000L) {
            exoPlayer.seekTo(savedMs)
        }
        exoPlayer.play()
        playbackError = null

        val listener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_ENDED) {
                    // Mark finished
                    prefs.edit().remove("resume_${episode.id}_${currentPartIndex}").apply()
                    // Sequential playback: Auto-advance to next part
                    if (currentPartIndex + 1 < parts.size) {
                        currentPartIndex += 1
                    }
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                playbackError = "無法直接播放此串流（網址或格式限制）：${error.message}"
            }
        }

        exoPlayer.addListener(listener)

        onDispose {
            val pos = exoPlayer.currentPosition
            val dur = exoPlayer.duration
            if (pos > 3000L && (dur <= 0L || pos < dur - 10000L)) {
                prefs.edit().putLong("resume_${episode.id}_${currentPartIndex}", pos).apply()
            }
            exoPlayer.removeListener(listener)
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            exoPlayer.release()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        AndroidView(
            factory = { ctx ->
                PlayerView(ctx).apply {
                    player = exoPlayer
                    useController = true
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // OSD Overlay
        if (isOsdVisible) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(40.dp)
            ) {
                Row(
                    modifier = Modifier.align(Alignment.TopStart),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Button(
                        onClick = onBack,
                        colors = ButtonDefaults.colors(
                            containerColor = Color(0xAA000000),
                            focusedContainerColor = NetflixRed
                        )
                    ) {
                        Text("← 返回", color = Color.White)
                    }
                    Spacer(modifier = Modifier.width(16.dp))
                    Text(
                        text = episode.title,
                        color = Color.White,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = currentPart.label,
                        color = NetflixRed,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                // Parts switcher chips
                Row(
                    modifier = Modifier.align(Alignment.BottomStart),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    parts.forEachIndexed { index, part ->
                        Button(
                            onClick = { currentPartIndex = index },
                            colors = ButtonDefaults.colors(
                                containerColor = if (index == currentPartIndex) NetflixRed else Color(0xAA222222),
                                focusedContainerColor = Color.White
                            )
                        ) {
                            Text(text = part.label, color = Color.White)
                        }
                    }
                }
            }
        }

        // Playback Error fallback dialog
        playbackError?.let { errorMsg ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xDD000000)),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(32.dp)
                ) {
                    Text(
                        text = "⚠️ 播放提示",
                        color = NetflixRed,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = errorMsg,
                        color = Color.White,
                        fontSize = 16.sp
                    )
                    Spacer(modifier = Modifier.height(24.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Button(
                            onClick = {
                                val demoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
                                exoPlayer.setMediaItem(MediaItem.fromUri(demoUrl))
                                exoPlayer.prepare()
                                exoPlayer.play()
                                playbackError = null
                            },
                            colors = ButtonDefaults.colors(
                                containerColor = NetflixRed,
                                focusedContainerColor = Color.White
                            )
                        ) {
                            Text("播放測試影片 (Demo)")
                        }
                        Button(
                            onClick = onBack,
                            colors = ButtonDefaults.colors(
                                containerColor = Color(0xFF333333),
                                focusedContainerColor = Color.White
                            )
                        ) {
                            Text("返回主畫面")
                        }
                    }
                }
            }
        }
    }
}
