// Shared helpers: discover the running Splynek.app via the fleet
// descriptor, then issue REST calls against its local HTTP API.
//
// Descriptor path: ~/Library/Application Support/Splynek/fleet.json
//   { port, token, deviceName, deviceUUID, schemeVersion }
//
// The Raycast extension never starts its own network listener; it only
// talks loopback to a running app. No credentials leave the machine.

import { homedir } from "os";
import { join } from "path";
import { readFileSync } from "fs";

export type FleetDescriptor = {
  port: number;
  token: string;
  deviceName: string;
  deviceUUID: string;
  schemeVersion: number;
};

export type ActiveJob = {
  url: string;
  filename: string;
  outputPath: string;
  totalBytes: number;
  downloaded: number;
  chunkSize: number;
  completedChunks: number[];
};

export type HistoryEntry = {
  url: string;
  filename: string;
  outputPath: string;
  totalBytes: number;
  finishedAt: string;
  sha256?: string;
};

export function descriptorPath(): string {
  return join(homedir(), "Library/Application Support/Splynek/fleet.json");
}

export function loadDescriptor(): FleetDescriptor {
  try {
    const raw = readFileSync(descriptorPath(), "utf-8");
    return JSON.parse(raw) as FleetDescriptor;
  } catch (e) {
    throw new Error(
      `Splynek isn't running — no fleet descriptor at ${descriptorPath()}. ` +
        `Launch Splynek.app and try again.`
    );
  }
}

export async function submit(
  action: "download" | "queue",
  url: string
): Promise<void> {
  const d = loadDescriptor();
  const res = await fetch(
    `http://127.0.0.1:${d.port}/splynek/v1/api/${action}?t=${encodeURIComponent(d.token)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ url }),
    }
  );
  if (res.status === 401) {
    throw new Error("Fleet token rejected. Re-open Splynek's About view and refresh the dashboard.");
  }
  if (res.status !== 202) {
    throw new Error(`Splynek returned HTTP ${res.status}.`);
  }
}

export async function fetchJobs(): Promise<ActiveJob[]> {
  const d = loadDescriptor();
  const res = await fetch(`http://127.0.0.1:${d.port}/splynek/v1/api/jobs`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return (await res.json()) as ActiveJob[];
}

export async function cancelAll(): Promise<void> {
  const d = loadDescriptor();
  const res = await fetch(
    `http://127.0.0.1:${d.port}/splynek/v1/api/cancel?t=${encodeURIComponent(d.token)}`,
    { method: "POST" }
  );
  if (res.status !== 202) throw new Error(`HTTP ${res.status}`);
}

export function fmtBytes(n: number): string {
  if (n <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.min(units.length - 1, Math.floor(Math.log(n) / Math.log(1024)));
  return (n / Math.pow(1024, i)).toFixed(i ? 1 : 0) + " " + units[i];
}
