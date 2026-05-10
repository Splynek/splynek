// Copyright © 2026 Splynek. MIT.
//
// submit-url.tsx — Raycast Form for queuing a URL on the Mac.

import {
  Action,
  ActionPanel,
  Form,
  Toast,
  showToast,
  popToRoot,
} from "@raycast/api";
import { useState } from "react";
import { submitURL } from "./api";

export default function SubmitURLCommand(): JSX.Element {
  const [url, setUrl] = useState("");
  const [action, setAction] = useState<"queue" | "download">("queue");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit() {
    if (!url.trim()) {
      await showToast({ style: Toast.Style.Failure, title: "URL is empty" });
      return;
    }
    setSubmitting(true);
    const result = await submitURL(url.trim(), action);
    setSubmitting(false);
    if (result.ok) {
      await showToast({
        style: Toast.Style.Success,
        title: action === "queue" ? "Queued on Splynek" : "Started on Splynek",
        message: url.trim(),
      });
      await popToRoot();
    } else {
      await showToast({
        style: Toast.Style.Failure,
        title: "Couldn't reach Splynek",
        message: result.message,
      });
    }
  }

  return (
    <Form
      isLoading={submitting}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Send to Splynek" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField
        id="url"
        title="URL"
        placeholder="https://…"
        value={url}
        onChange={setUrl}
      />
      <Form.Dropdown
        id="action"
        title="Action"
        value={action}
        onChange={(v) => setAction(v as "queue" | "download")}
      >
        <Form.Dropdown.Item value="queue" title="Queue (start when ready)" />
        <Form.Dropdown.Item value="download" title="Start downloading now" />
      </Form.Dropdown>
    </Form>
  );
}
