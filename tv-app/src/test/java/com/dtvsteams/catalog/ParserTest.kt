package com.dtvsteams.catalog

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.InputStreamReader

class ParserTest {

    private fun loadFixture(name: String): String {
        val stream = javaClass.classLoader?.getResourceAsStream("fixtures/$name")
            ?: error("Fixture not found: fixtures/$name")
        return InputStreamReader(stream, Charsets.UTF_8).use { it.readText() }
    }

    @Test
    fun parseList_returns10ItemsFromFixture() {
        val html = loadFixture("list.html")
        val episodes = Parser.parseList(html)

        assertEquals(10, episodes.size)
        assertEquals("綜藝玩很大 2026-10-04 嘉義 命運奪壘賽", episodes[0].title)
        assertEquals("2026-10-04", episodes[0].date)
        assertEquals("https://srgoideas.com/ep1/", episodes[0].url)
        assertEquals("https://srgoideas.com/ep1/", episodes[0].id)
    }

    @Test
    fun parseParts_returns3PartsFromFixture() {
        val html = loadFixture("episode.html")
        val parts = Parser.parseParts(html, "https://srgoideas.com/ep1/")

        assertEquals(3, parts.size)
        assertEquals("Part 1", parts[0].label)
        assertEquals("https://srgoideas.com/ep1/", parts[0].url)

        assertEquals("Part 2", parts[1].label)
        assertEquals("https://srgoideas.com/ep1/2/", parts[1].url)

        assertEquals("Part 3", parts[2].label)
        assertEquals("https://srgoideas.com/ep1/3/", parts[2].url)
    }

    @Test
    fun parseVideoUrl_extractsMp4Source() {
        val html = loadFixture("episode.html")
        val videoUrl = Parser.parseVideoUrl(html)

        assertNotNull(videoUrl)
        assertTrue(videoUrl!!.startsWith("https://example.xyz/vplay-001.mp4"))
    }
}
