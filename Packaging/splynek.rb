# typed: strict
# frozen_string_literal: true

cask "splynek" do
  version "2.0.0"
  # SHA-256 of the notarized + stapled v2.0.0 DMG cut
  # 2026-05-10 17:38.  Apple notarization submission ID
  # c92dfa2c-9240-4b6b-b406-ae7a447af239 (Accepted).
  # Re-compute via: shasum -a 256 build/Splynek.dmg
  sha256 "5404d86a7e069f5fc2ca6bf57f3760386e0a735309e944be0a4be76e3ebdd30f"

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
