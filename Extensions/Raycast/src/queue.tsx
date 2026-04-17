import { Clipboard, showHUD, showToast, Toast } from "@raycast/api";
import { submit } from "./fleet";

export default async function main() {
  const { text } = await Clipboard.read();
  const url = (text ?? "").trim();
  if (!url) {
    await showHUD("✗ Clipboard is empty");
    return;
  }
  try {
    await submit("queue", url);
    await showHUD(`＋ Queued in Splynek`);
  } catch (e) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Splynek",
      message: e instanceof Error ? e.message : String(e),
    });
  }
}
