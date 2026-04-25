import Foundation

// Each suite lives in a namespace enum with a static `run()` method that
// populates the harness. Adding a test is: write one file, wire it up
// here. Order matters for readability only — every test is independent.
print("Splynek tests — \(ISO8601DateFormatter().string(from: Date()))")
print("")

MerkleTreeTests.run()
BencodeTests.run()
MagnetTests.run()
TorrentV2VerifyTests.run()
DuplicateTests.run()
SanitizeTests.run()
WebDashboardTests.run()
QRCodeTests.run()
OpenAPITests.run()
FleetDescriptorTests.run()
LiveTorrentPhaseTests.run()
WatchedFolderTests.run()
PhaseOverRESTTests.run()
UsageCSVTests.run()
UsageTimelineTests.run()
GatekeeperDetailTests.run()
TorrentResumeTests.run()
SovereigntyCatalogTests.run()
TrustCatalogTests.run()

// v0.44: ConciergeTests, DownloadScheduleTests, LicenseValidatorTests,
// RecipeParserTests moved with their sources to the private
// Splynek/splynek-pro repo.

TestHarness.finish()
