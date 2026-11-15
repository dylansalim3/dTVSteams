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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.foundation.lazy.list.TvLazyColumn
import androidx.tv.foundation.lazy.list.itemsIndexed
import androidx.tv.material3.Button
import androidx.tv.material3.ButtonDefaults
import androidx.tv.material3.Text
import com.dtvsteams.catalog.Episode
import com.dtvsteams.catalog.Part

@Composable
fun DetailsScreen(
    episode: Episode,
    onPlayPart: (Int) -> Unit,
    onBack: () -> Unit
) {
    val parts = if (episode.parts.isNotEmpty()) episode.parts else listOf(
        Part("Part 1", episode.url, "完整集數 (上)", "35分"),
        Part("Part 2", "${episode.url}2/", "精彩對決 (中)", "38分"),
        Part("Part 3", "${episode.url}3/", "最終勝負 (下)", "35分")
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(NetflixDark)
            .padding(48.dp)
    ) {
        TvLazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Button(
                        onClick = onBack,
                        colors = ButtonDefaults.colors(
                            containerColor = Color(0xFF333333),
                            focusedContainerColor = Color.White
                        )
                    ) {
                        Text("← 返回", color = Color.White)
                    }
                    Spacer(modifier = Modifier.width(24.dp))
                    Text(
                        text = episode.title,
                        color = Color.White,
                        fontSize = 26.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            item {
                Text(
                    text = episode.overview.ifEmpty { "黃隊與黑隊前進嘉義阿里山展開命運奪壘戰！" },
                    color = Color(0xFFCCCCCC),
                    fontSize = 16.sp,
                    lineHeight = 24.sp,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }

            item {
                Text(
                    text = "分段選擇 (Parts)",
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 16.dp, bottom = 8.dp)
                )
            }

            itemsIndexed(parts) { index, part ->
                PartItem(
                    part = part,
                    index = index,
                    onClick = { onPlayPart(index) }
                )
            }
        }
    }
}

@Composable
fun PartItem(
    part: Part,
    index: Int,
    onClick: () -> Unit
) {
    var isFocused by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(if (isFocused) Color(0xFF333333) else NetflixCardBg)
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = if (isFocused) NetflixRed else Color.Transparent,
                shape = RoundedCornerShape(8.dp)
            )
            .onFocusChanged { isFocused = it.isFocused }
            .focusable()
            .clickable { onClick() }
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "${index + 1}",
                color = Color(0xFFAAAAAA),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.width(32.dp)
            )
            Column {
                Text(
                    text = part.title.ifEmpty { part.label },
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = part.label,
                    color = Color(0xFFAAAAAA),
                    fontSize = 13.sp
                )
            }
        }

        Text(
            text = part.duration,
            color = Color(0xFFAAAAAA),
            fontSize = 14.sp
        )
    }
}
