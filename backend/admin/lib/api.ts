import {
  getToken,
  getRefreshToken,
  setTokens,
  clearTokens,
} from "./auth";

function normalizeBaseUrl(raw: string) {
  const s = String(raw || "").trim();
  if (!s) return "";
  return s.endsWith("/") ? s.slice(0, -1) : s;
}

export const API_URL = normalizeBaseUrl(
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001"
);

function getCookie(name: string) {
  if (typeof document === "undefined") return null;
  const m = document.cookie.match(new RegExp(`(?:^|; )${name}=([^;]*)`));
  return m ? decodeURIComponent(m[1]) : null;
}

function isFormData(body: any): body is FormData {
  return typeof FormData !== "undefined" && body instanceof FormData;
}

function safeJson(text: string) {
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

function buildUrl(path: string) {
  const finalPath = path.startsWith("/") ? path : `/${path}`;
  return `${API_URL}${finalPath}`;
}

function buildHeaders(init: RequestInit = {}, token?: string | null) {
  const headers = new Headers(init.headers || {});

  if (init.body && !headers.has("Content-Type") && !isFormData(init.body)) {
    headers.set("Content-Type", "application/json");
  }

  if (token && !headers.has("Authorization")) {
    headers.set("Authorization", `Bearer ${token}`);
  }

  return headers;
}

async function rawFetch(
  path: string,
  init: RequestInit = {},
  token?: string | null
) {
  const url = buildUrl(path);
  const headers = buildHeaders(init, token);

  try {
    return await fetch(url, {
      ...init,
      headers,
      credentials: "include",
    });
  } catch (e: any) {
    console.error("API network error:", url, e?.message);
    throw new Error("API connection failed");
  }
}

let refreshPromise: Promise<string | null> | null = null;

async function refreshAccessToken(): Promise<string | null> {
  if (refreshPromise) {
    return refreshPromise;
  }

  refreshPromise = (async () => {
    const refreshToken =
      getRefreshToken?.() || getCookie("refresh_token") || null;

    if (!refreshToken) {
      return null;
    }

    const res = await rawFetch(
      "/auth/refresh",
      {
        method: "POST",
        body: JSON.stringify({ refreshToken }),
      },
      null
    );

    const text = await res.text();
    const data = text ? safeJson(text) : null;

    if (!res.ok) {
      clearTokens();
      return null;
    }

    const nextAccessToken = (data as any)?.accessToken ?? null;
    const nextRefreshToken = (data as any)?.refreshToken ?? null;

    if (!nextAccessToken || !nextRefreshToken) {
      clearTokens();
      return null;
    }

    setTokens(nextAccessToken, nextRefreshToken);
    return nextAccessToken;
  })();

  try {
    return await refreshPromise;
  } finally {
    refreshPromise = null;
  }
}

export async function apiFetch(path: string, init: RequestInit = {}) {
  const token = getToken?.() || getCookie("access_token");

  let res = await rawFetch(path, init, token);

  if (res.status === 401) {
    const nextAccessToken = await refreshAccessToken();

    if (nextAccessToken) {
      res = await rawFetch(path, init, nextAccessToken);
    }
  }

  const text = await res.text();
  const data = text ? safeJson(text) : null;

  if (!res.ok) {
    const msg =
      (data as any)?.message ||
      (data as any)?.error ||
      (data as any)?.raw ||
      `HTTP ${res.status}`;

    if (res.status === 401) {
      clearTokens();
      if (typeof window !== "undefined") {
        window.location.href = "/login";
      }
    }

    if (Array.isArray(msg)) {
      throw new Error(msg.join("; "));
    }

    throw new Error(typeof msg === "string" ? msg : JSON.stringify(msg));
  }

  return data;
}