package com.dtvsteams.catalog

data class Episode(val id: String, val title: String, val date: String, val url: String)
data class Part(val label: String, val url: String)

object Parser {
  // Same selectors as catalog-core/src/parser.ts (port)
  fun parseList(html: String): List<Episode> {
    // Uses Jsoup on device: doc.select("ul.lcp_catlist a")
    return emptyList() // wired in Android Studio with Jsoup dep
  }
  fun parseParts(html: String, baseUrl: String): List<Part> {
    // Uses Jsoup: doc.select("ul.contentlist li")
    return emptyList()
  }
}

object Cache {
  data class CachedCatalog(val updatedAt: String, val episodes: List<Episode>, val error: String? = null)
  fun shouldRefresh(updatedAt: String, ttlMs: Long, nowMs: Long = System.currentTimeMillis()): Boolean {
    val t = try { java.time.Instant.parse(updatedAt).toEpochMilli() } catch (e: Exception) { return true }
    return nowMs - t > ttlMs
  }
}
