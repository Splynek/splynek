// Copyright © 2026 Splynek. MIT.
//
// api.ts — shared HTTP client for Splynek Mac REST endpoints.
//
// Uses the persistent API token shipped in Sprint 4
// (`088d8d1`) — same `?t=<token>` query param the session
// webToken uses.  All commands read host / port / apiToken from
// Raycast preferences via `getPreferenceValues`.
//
// Failure shape: every call returns { ok: true, data } or
// { ok: false, message } so callers can surface clean toasts
// without try/catch sprawl.

import { getPreferenceValues } from "@raycast/api";

interface Preferences {
  host: string;
  port: string;
  apiToken: string;
}

export type ApiResult<T> =
  | { ok: true; data: T }
  | { ok: false; message: string };

function baseURL(): string {
  const prefs = getPreferenceValues<Preferences>();
  return `http://${prefs.host}:${prefs.port}`;
}

function authQuery(): string {
  const prefs = getPreferenceValues<Preferences>();
  return `?t=${encodeURIComponent(prefs.apiToken)}`;
}

async function get<T>(path: string): Promise<ApiResult<T>> {
  try {
    const url = `${baseURL()}${path}${authQuery()}`;
    const response = await fetch(url);
    if (!response.ok) {
      return {
        ok: false,
        message: `Splynek returned ${response.status} ${response.statusText}`,
      };
    }
    const data = (await response.json()) as T;
    return { ok: true, data };
  } catch (error) {
    return {
      ok: false,
      message:
        error instanceof Error
          ? error.message
          : "Couldn't reach the Splynek Mac",
    };
  }
}

async function post(
  path: string,
  body?: object
): Promise<ApiResult<undefined>> {
  try {
    const url = `${baseURL()}${path}${authQuery()}`;
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!response.ok) {
      return {
        ok: false,
        message: `Splynek returned ${response.status} ${response.statusText}`,
      };
    }
    return { ok: true, data: undefined };
  } catch (error) {
    return {
      ok: false,
      message:
        error instanceof Error
          ? error.message
          : "Couldn't reach the Splynek Mac",
    };
  }
}

// ─── Typed wrappers ────────────────────────────────────────────

export interface ActiveJob {
  id: string;
  url: string;
  filename: string | null;
  phase: string | null; // "running" | "queued" | "paused" | ...
  bytesDownloaded?: number;
  bytesTotal?: number;
  throughputBps?: number;
}

export function fetchActiveJobs(): Promise<ApiResult<ActiveJob[]>> {
  return get<ActiveJob[]>("/splynek/v1/api/jobs");
}

export interface SovereigntyTopApp {
  bundleID: string;
  displayName: string;
  firstAlternative: string | null;
}

export interface SovereigntySummary {
  score: number;
  totalApps: number;
  appsWithAlternatives: number;
  topConcerns: SovereigntyTopApp[];
  generatedAt: string;
}

export function fetchSovereigntySummary(): Promise<
  ApiResult<SovereigntySummary>
> {
  return get<SovereigntySummary>("/splynek/v1/api/sovereignty/summary");
}

export function submitURL(
  url: string,
  action: "queue" | "download" = "queue"
): Promise<ApiResult<undefined>> {
  return post(`/splynek/v1/api/${action}`, { url });
}

export function pauseAll(): Promise<ApiResult<undefined>> {
  return post("/splynek/v1/api/pause-all");
}

export function resumeAll(): Promise<ApiResult<undefined>> {
  return post("/splynek/v1/api/resume-all");
}
