// Copyright © 2026 Splynek. MIT.
//
// sovereignty-score.tsx — Raycast Detail showing Sovereignty
// score + top concerns.

import { Action, ActionPanel, Detail, Icon } from "@raycast/api";
import { useEffect, useState } from "react";
import { fetchSovereigntySummary, SovereigntySummary } from "./api";

export default function SovereigntyScoreCommand(): JSX.Element {
  const [summary, setSummary] = useState<SovereigntySummary | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      const r = await fetchSovereigntySummary();
      setLoading(false);
      if (r.ok) {
        setSummary(r.data);
      } else {
        setError(r.message);
      }
    })();
  }, []);

  const markdown = renderMarkdown({ summary, error, loading });

  return (
    <Detail
      isLoading={loading}
      markdown={markdown}
      actions={
        summary && summary.topConcerns.length > 0 ? (
          <ActionPanel>
            <Action.OpenInBrowser
              url="https://splynek.app/sovereignty"
              title="Read About Sovereignty"
            />
          </ActionPanel>
        ) : undefined
      }
    />
  );
}

function renderMarkdown(args: {
  summary: SovereigntySummary | null;
  error: string | null;
  loading: boolean;
}): string {
  if (args.error) {
    return `# Couldn't reach Splynek\n\n${args.error}\n\nCheck the host / port / API token in Raycast preferences.`;
  }
  if (!args.summary) {
    return args.loading ? "" : "# No data yet\n\nOpen Sovereignty on the Mac to scan.";
  }
  const s = args.summary;
  const emoji = s.score >= 80 ? "🟢" : s.score >= 50 ? "🟡" : "🔴";
  const lines: string[] = [];
  lines.push(`# ${emoji} Sovereignty score: **${s.score}** / 100`);
  lines.push("");
  lines.push(
    `**${s.appsWithAlternatives}** of **${s.totalApps}** installed apps have an EU/OSS alternative listed in the catalog.`
  );
  if (s.topConcerns.length > 0) {
    lines.push("");
    lines.push("## Top concerns");
    for (const app of s.topConcerns) {
      const altSuffix = app.firstAlternative
        ? ` → **${app.firstAlternative}**`
        : "";
      lines.push(`- ${app.displayName}${altSuffix}`);
    }
  }
  lines.push("");
  lines.push(`*Generated ${prettyDate(s.generatedAt)}*`);
  return lines.join("\n");
}

function prettyDate(iso: string): string {
  try {
    const d = new Date(iso);
    return d.toLocaleString();
  } catch {
    return iso;
  }
}
