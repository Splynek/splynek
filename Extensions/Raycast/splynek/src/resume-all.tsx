// Copyright © 2026 Splynek. MIT.
//
// resume-all.tsx — no-view Raycast command for one-tap resume.

import { Toast, showToast } from "@raycast/api";
import { resumeAll } from "./api";

export default async function ResumeAllCommand(): Promise<void> {
  const r = await resumeAll();
  if (r.ok) {
    await showToast({
      style: Toast.Style.Success,
      title: "Resumed all downloads",
    });
  } else {
    await showToast({
      style: Toast.Style.Failure,
      title: "Resume failed",
      message: r.message,
    });
  }
}
