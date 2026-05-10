// Copyright © 2026 Splynek. MIT.
//
// active-downloads.tsx — Raycast List of in-flight downloads.

import {
  Action,
  ActionPanel,
  Color,
  Icon,
  List,
  Toast,
  showToast,
} from "@raycast/api";
import { useEffect, useState } from "react";
import { ActiveJob, fetchActiveJobs, pauseAll, resumeAll } from "./api";

export default function ActiveDownloadsCommand(): JSX.Element {
  const [jobs, setJobs] = useState<ActiveJob[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function refresh() {
    setLoading(true);
    const result = await fetchActiveJobs();
    setLoading(false);
    if (result.ok) {
      setJobs(result.data);
      setError(null);
    } else {
      setError(result.message);
    }
  }

  // Poll every 3s while the view is mounted.  Raycast keeps
  // a list visible only while the user has it open; no
  // long-running cost.
  useEffect(() => {
    refresh();
    const id = setInterval(refresh, 3000);
    return () => clearInterval(id);
  }, []);

  return (
    <List
      isLoading={loading}
      searchBarPlaceholder="Filter by filename"
      actions={
        <ActionPanel>
          <PauseResumeActions />
        </ActionPanel>
      }
    >
      {error && (
        <List.EmptyView
          icon={{ source: Icon.ExclamationMark, tintColor: Color.Red }}
          title="Couldn't reach Splynek"
          description={error}
        />
      )}
      {!error && jobs.length === 0 && !loading && (
        <List.EmptyView
          icon={Icon.Tray}
          title="No active downloads"
          description="Queue a URL with Submit URL to Splynek."
        />
      )}
      {jobs.map((job) => (
        <List.Item
          key={job.id}
          title={job.filename ?? job.url}
          subtitle={subtitleFor(job)}
          accessories={[
            { text: phaseLabel(job.phase), icon: phaseIcon(job.phase) },
          ]}
          actions={
            <ActionPanel>
              <Action.OpenInBrowser url={job.url} title="Open Source URL" />
              <Action.CopyToClipboard
                content={job.url}
                title="Copy Source URL"
              />
              <PauseResumeActions />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}

function subtitleFor(job: ActiveJob): string | undefined {
  if (job.bytesTotal && job.bytesDownloaded !== undefined) {
    const pct = Math.floor((job.bytesDownloaded / job.bytesTotal) * 100);
    return `${pct}% · ${humanBytes(job.bytesDownloaded)} of ${humanBytes(job.bytesTotal)}`;
  }
  return undefined;
}

function phaseLabel(phase: string | null): string {
  switch (phase) {
    case "running":
      return "Running";
    case "paused":
      return "Paused";
    case "queued":
      return "Queued";
    case "finished":
      return "Done";
    case "failed":
      return "Failed";
    default:
      return phase ?? "—";
  }
}

function phaseIcon(phase: string | null): { source: Icon; tintColor: Color } {
  switch (phase) {
    case "running":
      return { source: Icon.Play, tintColor: Color.Green };
    case "paused":
      return { source: Icon.Pause, tintColor: Color.Orange };
    case "queued":
      return { source: Icon.Clock, tintColor: Color.SecondaryText };
    case "finished":
      return { source: Icon.Checkmark, tintColor: Color.Green };
    case "failed":
      return { source: Icon.ExclamationMark, tintColor: Color.Red };
    default:
      return { source: Icon.Circle, tintColor: Color.SecondaryText };
  }
}

function humanBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024)
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

// ─── Shared bulk actions ─────────────────────────────────

function PauseResumeActions(): JSX.Element {
  return (
    <>
      <Action
        title="Pause All"
        icon={Icon.Pause}
        shortcut={{ modifiers: ["cmd"], key: "p" }}
        onAction={async () => {
          const r = await pauseAll();
          if (r.ok) {
            await showToast({ style: Toast.Style.Success, title: "Paused all" });
          } else {
            await showToast({
              style: Toast.Style.Failure,
              title: "Pause failed",
              message: r.message,
            });
          }
        }}
      />
      <Action
        title="Resume All"
        icon={Icon.Play}
        shortcut={{ modifiers: ["cmd"], key: "r" }}
        onAction={async () => {
          const r = await resumeAll();
          if (r.ok) {
            await showToast({
              style: Toast.Style.Success,
              title: "Resumed all",
            });
          } else {
            await showToast({
              style: Toast.Style.Failure,
              title: "Resume failed",
              message: r.message,
            });
          }
        }}
      />
    </>
  );
}
