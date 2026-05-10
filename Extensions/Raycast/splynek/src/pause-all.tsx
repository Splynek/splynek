// Copyright © 2026 Splynek. MIT.
//
// pause-all.tsx — no-view Raycast command for one-tap pause.
// Wired in package.json with mode: "no-view"; runs without
// presenting a view, surfaces a toast with the result.

import { Toast, showToast } from "@raycast/api";
import { pauseAll } from "./api";

export default async function PauseAllCommand(): Promise<void> {
  const r = await pauseAll();
  if (r.ok) {
    await showToast({
      style: Toast.Style.Success,
      title: "Paused all downloads",
    });
  } else {
    await showToast({
      style: Toast.Style.Failure,
      title: "Pause failed",
      message: r.message,
    });
  }
}
