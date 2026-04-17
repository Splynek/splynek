import { ActionPanel, Action, List, Icon, showToast, Toast } from "@raycast/api";
import { useState, useEffect, useCallback } from "react";
import { fetchJobs, cancelAll, fmtBytes, ActiveJob } from "./fleet";

// Live list of active downloads. Polls the local API every 1.5 s
// while the view is open; same polling cadence as the web dashboard.
export default function Status() {
  const [jobs, setJobs] = useState<ActiveJob[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const list = await fetchJobs();
      setJobs(list);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, 1500);
    return () => clearInterval(id);
  }, [refresh]);

  const onCancel = async () => {
    try {
      await cancelAll();
      await showToast({ style: Toast.Style.Success, title: "Cancelled all" });
      refresh();
    } catch (e) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Cancel failed",
        message: e instanceof Error ? e.message : String(e),
      });
    }
  };

  if (error) {
    return (
      <List>
        <List.EmptyView
          icon={Icon.Warning}
          title="Splynek unreachable"
          description={error}
        />
      </List>
    );
  }

  return (
    <List isLoading={jobs === null} searchBarPlaceholder="Filter active downloads">
      {jobs && jobs.length === 0 && (
        <List.EmptyView
          icon={Icon.ArrowDownCircle}
          title="No active downloads"
          description="Paste a URL into Splynek or use the Download command."
        />
      )}
      {jobs?.map((j) => {
        const pct = j.totalBytes > 0 ? (j.downloaded / j.totalBytes) * 100 : 0;
        return (
          <List.Item
            key={j.url}
            icon={Icon.ArrowDownCircle}
            title={j.filename}
            subtitle={j.url}
            accessories={[
              { text: `${pct.toFixed(1)}%` },
              { text: `${fmtBytes(j.downloaded)} / ${fmtBytes(j.totalBytes)}` },
            ]}
            actions={
              <ActionPanel>
                <Action.CopyToClipboard title="Copy URL" content={j.url} />
                <Action
                  title="Cancel All Downloads"
                  style={Action.Style.Destructive}
                  icon={Icon.Stop}
                  onAction={onCancel}
                />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
