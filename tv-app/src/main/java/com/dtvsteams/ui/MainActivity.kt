package com.dtvsteams.ui

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.*
import com.dtvsteams.catalog.Cache
import com.dtvsteams.catalog.Episode

enum class TVScreenState {
    HOME,
    DETAILS,
    PLAYER
}

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            var currentScreen by remember { mutableStateOf(TVScreenState.HOME) }
            var selectedEpisode by remember { mutableStateOf<Episode?>(null) }
            var selectedPartIndex by remember { mutableStateOf(0) }
            var catalogEpisodes by remember { mutableStateOf<List<Episode>>(emptyList()) }

            LaunchedEffect(Unit) {
                val cached = Cache.loadCache(this@MainActivity)
                if (cached.episodes.isNotEmpty()) {
                    catalogEpisodes = cached.episodes
                } else {
                    // Fallback initial sample episode
                    catalogEpisodes = listOf(
                        Episode(
                            id = "https://srgoideas.com/ep1/",
                            title = "綜藝玩很大 2026-10-04 嘉義 命運奪壘賽",
                            date = "2026-10-04",
                            url = "https://srgoideas.com/ep1/",
                            overview = "黃隊與黑隊前進嘉義阿里山展開命運奪壘戰！"
                        )
                    )
                }
            }

            when (currentScreen) {
                TVScreenState.HOME -> {
                    HomeScreen(
                        episodes = catalogEpisodes,
                        onPlayEpisode = { ep, partIdx ->
                            selectedEpisode = ep
                            selectedPartIndex = partIdx
                            currentScreen = TVScreenState.PLAYER
                        },
                        onOpenDetails = { ep ->
                            selectedEpisode = ep
                            currentScreen = TVScreenState.DETAILS
                        },
                        onRefresh = {
                            Toast.makeText(this@MainActivity, "快取已更新", Toast.LENGTH_SHORT).show()
                        }
                    )
                }
                TVScreenState.DETAILS -> {
                    selectedEpisode?.let { ep ->
                        DetailsScreen(
                            episode = ep,
                            onPlayPart = { partIdx ->
                                selectedPartIndex = partIdx
                                currentScreen = TVScreenState.PLAYER
                            },
                            onBack = { currentScreen = TVScreenState.HOME }
                        )
                    } ?: run {
                        currentScreen = TVScreenState.HOME
                    }
                }
                TVScreenState.PLAYER -> {
                    selectedEpisode?.let { ep ->
                        PlayerScreen(
                            episode = ep,
                            initialPartIndex = selectedPartIndex,
                            onBack = { currentScreen = TVScreenState.HOME }
                        )
                    } ?: run {
                        currentScreen = TVScreenState.HOME
                    }
                }
            }
        }
    }
}
