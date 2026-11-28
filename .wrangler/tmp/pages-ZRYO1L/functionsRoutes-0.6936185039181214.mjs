import { onRequestGet as __api_episodes_js_onRequestGet } from "C:\\Users\\Dylan\\Documents\\github\\dTVSteams\\functions\\api\\episodes.js"
import { onRequestOptions as __api_episodes_js_onRequestOptions } from "C:\\Users\\Dylan\\Documents\\github\\dTVSteams\\functions\\api\\episodes.js"
import { onRequestGet as __api_resolve_stream_js_onRequestGet } from "C:\\Users\\Dylan\\Documents\\github\\dTVSteams\\functions\\api\\resolve-stream.js"
import { onRequestOptions as __api_resolve_stream_js_onRequestOptions } from "C:\\Users\\Dylan\\Documents\\github\\dTVSteams\\functions\\api\\resolve-stream.js"
import { onRequestGet as __api_thumbnail_js_onRequestGet } from "C:\\Users\\Dylan\\Documents\\github\\dTVSteams\\functions\\api\\thumbnail.js"
import { onRequestOptions as __api_thumbnail_js_onRequestOptions } from "C:\\Users\\Dylan\\Documents\\github\\dTVSteams\\functions\\api\\thumbnail.js"
import { onRequest as __api_stream_js_onRequest } from "C:\\Users\\Dylan\\Documents\\github\\dTVSteams\\functions\\api\\stream.js"

export const routes = [
    {
      routePath: "/api/episodes",
      mountPath: "/api",
      method: "GET",
      middlewares: [],
      modules: [__api_episodes_js_onRequestGet],
    },
  {
      routePath: "/api/episodes",
      mountPath: "/api",
      method: "OPTIONS",
      middlewares: [],
      modules: [__api_episodes_js_onRequestOptions],
    },
  {
      routePath: "/api/resolve-stream",
      mountPath: "/api",
      method: "GET",
      middlewares: [],
      modules: [__api_resolve_stream_js_onRequestGet],
    },
  {
      routePath: "/api/resolve-stream",
      mountPath: "/api",
      method: "OPTIONS",
      middlewares: [],
      modules: [__api_resolve_stream_js_onRequestOptions],
    },
  {
      routePath: "/api/thumbnail",
      mountPath: "/api",
      method: "GET",
      middlewares: [],
      modules: [__api_thumbnail_js_onRequestGet],
    },
  {
      routePath: "/api/thumbnail",
      mountPath: "/api",
      method: "OPTIONS",
      middlewares: [],
      modules: [__api_thumbnail_js_onRequestOptions],
    },
  {
      routePath: "/api/stream",
      mountPath: "/api",
      method: "",
      middlewares: [],
      modules: [__api_stream_js_onRequest],
    },
  ]