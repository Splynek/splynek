# Homebrew cask template for Splynek. Submit to homebrew/cask by
# copying this file into Casks/splynek.rb of a homebrew-cask fork,
# with `version`, `sha256`, and `url` filled in from a real release.
#
# The file is a template; fields marked `FILL IN` will fail `brew
# audit --new --cask Casks/splynek.rb` until they're real.

cask "splynek" do
  version "1.5.3"
  sha256 "4fe61bab5ee2eb847d789c7f8b2245bf6b180936ec231241284f20b968c0e6cb"

  url "https://github.com/Splynek/splynek/releases/download/v#{version}/Splynek-#{version}.dmg",
      verified: "github.com/Splynek/"
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
