# typed: strict
# frozen_string_literal: true

cask "splynek" do
  version "1.6.1"
  # ⚠️  sha256 placeholder — replace with the real hash once the
  # v1.5.6 DMG is built + uploaded to GitHub Releases.
  # Compute via: shasum -a 256 dist/Splynek-1.5.6.dmg
  sha256 :no_check

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
