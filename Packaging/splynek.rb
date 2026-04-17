# Homebrew cask template for Splynek. Submit to homebrew/cask by
# copying this file into Casks/splynek.rb of a homebrew-cask fork,
# with `version`, `sha256`, and `url` filled in from a real release.
#
# The file is a template; fields marked `FILL IN` will fail `brew
# audit --new --cask Casks/splynek.rb` until they're real.

cask "splynek" do
  version "0.27.0"            # FILL IN (must match a published tag)
  sha256 "FILL_IN_WITH_SHASUM_OF_DMG"

  # Drop this URL in after creating a GitHub Release that hosts the DMG.
  url "https://github.com/splynek/splynek/releases/download/v#{version}/Splynek.dmg",
      verified: "github.com/splynek/"
  name "Splynek"
  desc "Native macOS multi-interface download aggregator with BitTorrent v2"
  homepage "https://splynek.app/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "Splynek.app"

  # Splynek reads / writes:
  #   ~/Library/Application Support/Splynek/      (history, fleet.json, …)
  #   UserDefaults (app.splynek.Splynek)
  # These are cleaned up with `brew uninstall --zap`.
  zap trash: [
    "~/Library/Application Support/Splynek",
    "~/Library/Preferences/app.splynek.Splynek.plist",
    "~/Library/HTTPStorages/app.splynek.Splynek",
  ]
end
