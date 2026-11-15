package com.dtvsteams.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.foundation.lazy.list.TvLazyColumn
import androidx.tv.foundation.lazy.list.itemsIndexed
import androidx.tv.material3.Button
import androidx.tv.material3.ButtonDefaults
import androidx.tv.material3.Text
import com.dtvsteams.catalog.Episode

val YouTubeRed = Color(0xFFFF0000)
val YouTubeDark = Color(0xFF0F0F0F)
val YouTubeSurface = Color(0xFF181818)
val YouTubeCardBg = Color(0xFF212121)

@Composable
fun HomeScreen(
    episodes: List<Episode>,
    onPlayEpisode: (Episode, Int) -> Unit,
    onOpenDetails: (Episode) -> Unit,
    onRefresh: () -> Unit
) {
    var activeEpisode by remember { mutableStateOf(episodes.firstOrNull()) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(YouTubeDark)
            .padding(horizontal = 48.dp, vertical = 24.dp)
    ) {
        // YouTube TV Brand Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 20.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(36.dp, 26.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(YouTubeRed),
                    contentAlignment = Alignment.Center
                ) {
                    Text(text = "▶", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                }
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "dTVStream TV",
                    color = Color.White,
                    fontSize = 24.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "綜藝玩很大",
                    color = Color(0xFFAAAAAA),
                    fontSize = 16.sp
                )
            }

            Text(
                text = "共 ${episodes.size} 集 · 遙控器 1/2/3 鍵切換分段",
                color = Color(0xFFAAAAAA),
                fontSize = 14.sp
            )
        }

        // Active Selected Episode Spotlight
        activeEpisode?.let { ep ->
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(YouTubeSurface)
                    .padding(20.dp)
            ) {
                Column {
                    Text(
                        text = ep.title,
                        color = Color.White,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "${ep.date} · 1080p HD · 全集共 ${ep.parts.size.coerceAtLeast(3)} 個分段",
                        color = Color(0xFFAAAAAA),
                        fontSize = 13.sp
                    )
                    Spacer(modifier = Modifier.height(12.dp))

                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(
                            onClick = { onPlayEpisode(ep, 0) },
                            colors = ButtonDefaults.colors(
                                containerColor = YouTubeRed,
                                focusedContainerColor = Color.White
                            )
                        ) {
                            Text(text = "▶ 播放 Part 1", fontWeight = FontWeight.Bold)
                        }

                        if (ep.parts.size > 1) {
                            Button(
                                onClick = { onPlayEpisode(ep, 1) },
                                colors = ButtonDefaults.colors(
                                    containerColor = Color(0xFF333333),
                                    focusedContainerColor = YouTubeRed
                                )
                            ) {
                                Text(text = "▶ 播放 Part 2")
                            }
                        }

                        if (ep.parts.size > 2) {
                            Button(
                                onClick = { onPlayEpisode(ep, 2) },
                                colors = ButtonDefaults.colors(
                                    containerColor = Color(0xFF333333),
                                    focusedContainerColor = YouTubeRed
                                )
                            ) {
                                Text(text = "▶ 播放 Part 3")
                            }
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Simple List of Videos (YouTube Style)
        Text(
            text = "全部集數列表",
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(bottom = 12.dp)
        )

        TvLazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(bottom = 40.dp)
        ) {
            itemsIndexed(episodes) { index, ep ->
                YouTubeEpisodeListItem(
                    episode = ep,
                    isSelected = ep == activeEpisode,
                    onFocus = { activeEpisode = ep },
                    onPlayPart = { pIdx -> onPlayEpisode(ep, pIdx) }
                )
            }
        }
    }
}

@Composable
fun YouTubeEpisodeListItem(
    episode: Episode,
    isSelected: Boolean,
    onFocus: () -> Unit,
    onPlayPart: (Int) -> Unit
) {
    var isFocused by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(if (isSelected) Color(0xFF2A2A2A) else YouTubeCardBg)
            .border(
                width = if (isFocused) 3.dp else 1.dp,
                color = if (isFocused) YouTubeRed else Color.Transparent,
                shape = RoundedCornerShape(8.dp)
            )
            .onFocusChanged {
                isFocused = it.isFocused
                if (it.isFocused) onFocus()
            }
            .focusable()
            .clickable { onPlayPart(0) }
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = episode.title,
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "${episode.date} · 完整 3 段",
                    color = Color(0xFFAAAAAA),
                    fontSize = 13.sp
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = { onPlayPart(0) },
                    colors = ButtonDefaults.colors(
                        containerColor = Color(0xFF383838),
                        focusedContainerColor = YouTubeRed
                    )
                ) {
                    Text(text = "Part 1", fontSize = 12.sp)
                }

                Button(
                    onClick = { onPlayPart(1) },
                    colors = ButtonDefaults.colors(
                        containerColor = Color(0xFF383838),
                        focusedContainerColor = YouTubeRed
                    )
                ) {
                    Text(text = "Part 2", fontSize = 12.sp)
                }

                Button(
                    onClick = { onPlayPart(2) },
                    colors = ButtonDefaults.colors(
                        containerColor = Color(0xFF383838),
                        focusedContainerColor = YouTubeRed
                    )
                ) {
                    Text(text = "Part 3", fontSize = 12.sp)
                }
            }
        }
    }
}
