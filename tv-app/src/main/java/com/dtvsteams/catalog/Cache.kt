package com.dtvsteams.catalog

import android.content.Context
import com.google.gson.Gson
import java.io.File
import java.time.Instant

object Cache {
    data class CachedCatalog(
        val updatedAt: String,
        val episodes: List<Episode>,
        val error: String? = null
    )

    private const val CACHE_FILE_NAME = "catalog_cache.json"
    private val gson = Gson()

    fun shouldRefresh(updatedAt: String, ttlMs: Long, nowMs: Long = System.currentTimeMillis()): Boolean {
        val t = try {
            Instant.parse(updatedAt).toEpochMilli()
        } catch (e: Exception) {
            return true
        }
        return nowMs - t > ttlMs
    }

    fun loadCache(context: Context): CachedCatalog {
        val file = File(context.filesDir, CACHE_FILE_NAME)
        if (!file.exists()) {
            return CachedCatalog(updatedAt = "", episodes = emptyList())
        }
        return try {
            val json = file.readText(Charsets.UTF_8)
            gson.fromJson(json, CachedCatalog::class.java)
        } catch (e: Exception) {
            CachedCatalog(updatedAt = "", episodes = emptyList(), error = e.message)
        }
    }

    fun saveCache(context: Context, catalog: CachedCatalog) {
        try {
            val file = File(context.filesDir, CACHE_FILE_NAME)
            val json = gson.toJson(catalog)
            file.writeText(json, Charsets.UTF_8)
        } catch (ignored: Exception) {
        }
    }
}
