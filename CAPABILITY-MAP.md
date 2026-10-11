# Capability Map: dTVSteams Personal

Approved: 2026-10-11

| Module id | Responsibility | Depends on |
|---|---|---|
| catalog-core | Fetch list pages + episode pages, parse titles/dates/Part 1-2-3, cache to JSON, stale-while-revalidate | — |
| web-app | Netflix-style browse/search/play on web, on-entry auto-refresh + manual refresh button | catalog-core |
| tv-app | Android TV Leanback browse/play via ExoPlayer, same refresh model, D-pad focus | catalog-core |

Build order: catalog-core → web-app → tv-app
