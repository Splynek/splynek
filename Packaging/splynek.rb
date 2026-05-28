# typed: strict
# frozen_string_literal: true

cask "splynek" do
  version "3.0.0"
  # SHA-256 of the notarized + stapled v3.0.0 DMG.
  # Compute at release time (Phase C7):
  #   shasum -a 256 build/Splynek-3.0.0.dmg
  # Apple notarization submission ID
  # 3e3bef81-1aaa-42d3-9d19-adcdb4a41845 (Accepted).
  # v2.0.1 is a launchable-DMG hotfix for v2.0.0 — v2.0.0 was signed
  # with app-sandbox=true + iCloud entitlements without a provisioning
  # profile, which made Launchd refuse to spawn it (POSIX 163).
  # Re-compute via: shasum -a 256 build/Splynek.dmg
  sha256 "REPLACE_WITH_SHA256_OF_NOTARIZED_Splynek-3.0.0.dmg"

  url "https://github.com/Splynek/splynek/releases/download/v#{version}/Splynek-#{version}.dmg",
      verified: "github.com/Splynek/"
  name "Splynek"
  desc "Multi-interface download aggregator with BitTorrent v2"
  homepage "https://splynek.app/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "Splynek.app"

  zap trash: [
    "~/Library/Application Support/Splynek",
    "~/Library/HTTPStorages/app.splynek.Splynek",
    "~/Library/Preferences/app.splynek.Splynek.plist",
  ]
end
