import { Clipboard, showHUD, showToast, Toast } from "@raycast/api";
import { submit } from "./fleet";

// Entry point for the `Download URL with Splynek` command. Grabs the
// clipboard, hands it to the local Splynek, shows a HUD confirmation.
// `mode: "no-view"` in package.json means this runs without opening a
// Raycast window — the user gets a quick native toast instead.
export default async function main() {
  const { text } = await Clipboard.read();
  const url = (text ?? "").trim();
  if (!url) {
    await showHUD("✗ Clipboard is empty");
    return;
  }
  if (!url.startsWith("http") && !url.startsWith("magnet:")) {
    await showHUD("✗ Clipboard isn't a URL or magnet");
    return;
  }
  try {
    await submit("download", url);
    await showHUD(`↓ Splynek — ${url.length > 48 ? url.slice(0, 48) + "…" : url}`);
  } catch (e) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Splynek",
      message: e instanceof Error ? e.message : String(e),
    });
  }
}
