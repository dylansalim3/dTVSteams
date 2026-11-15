package com.dtvsteams.catalog

import org.jsoup.Jsoup

data class Episode(
    val id: String,
    val title: String,
    val date: String,
    val url: String,
    val overview: String = "",
    val backdrop: String = "",
    val poster: String = "",
    val match: Int = 98,
    val rating: String = "13+",
    val category: String = "trending",
    val top10: Int = 0,
    val parts: List<Part> = emptyList()
)

data class Part(
    val label: String,
    val url: String,
    val title: String = "",
    val duration: String = "35分"
)

object Parser {
    private val DATE_REGEX = Regex("""\d{4}-\d{2}-\d{2}""")

    fun parseList(html: String): List<Episode> {
        val doc = Jsoup.parse(html)
        val anchors = doc.select("ul.lcp_catlist a")
        val result = mutableListOf<Episode>()

        for (a in anchors) {
            val title = a.text().trim()
            val url = a.attr("href").trim()
            if (title.isEmpty() || url.isEmpty()) continue

            val match = DATE_REGEX.find(title)
            val date = match?.value ?: ""
            result.add(Episode(id = url, title = title, date = date, url = url))
        }
        return result
    }

    fun parseParts(html: String, baseUrl: String): List<Part> {
        val doc = Jsoup.parse(html, baseUrl)
        val items = doc.select("ul.contentlist li")
        val result = mutableListOf<Part>()

        for (li in items) {
            val a = li.selectFirst("a")
            if (a != null) {
                val label = a.text().trim()
                val url = a.absUrl("href").ifEmpty { a.attr("href") }.ifEmpty { baseUrl }
                result.add(Part(label = label, url = url))
            } else {
                val label = li.text().trim()
                if (label.isNotEmpty()) {
                    result.add(Part(label = label, url = baseUrl))
                }
            }
        }
        return result
    }

    fun parseVideoUrl(html: String): String? {
        val doc = Jsoup.parse(html)
        val src = doc.select("#playerdiv video source").attr("src").trim()
        return if (src.isNotEmpty()) src else null
    }
}

object Cache {
    data class CachedCatalog(val updatedAt: String, val episodes: List<Episode>, val error: String? = null)

    fun shouldRefresh(updatedAt: String, ttlMs: Long, nowMs: Long = System.currentTimeMillis()): Boolean {
        val t = try { java.time.Instant.parse(updatedAt).toEpochMilli() } catch (e: Exception) { return true }
        return nowMs - t > ttlMs
    }
}
