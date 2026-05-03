import Foundation

// Each suite lives in a namespace enum with a static `run()` method that
// populates the harness. Adding a test is: write one file, wire it up
// here. Order matters for readability only — every test is independent.
//
// v1.6.2: optional `--filter <substring>` (or `-f <substring>`) narrows
// the run.  Match is case-insensitive against `"<suite>: <test name>"`.
// Use it for fast iteration during debugging — `swift run splynek-test
// --filter Trust` runs only the Trust* suites.

let argv = CommandLine.arguments
for i in 1..<argv.count {
    if argv[i] == "--filter" || argv[i] == "-f", i + 1 < argv.count {
        TestHarness.filter = argv[i + 1]
        break
    }
}

print("Splynek tests — \(ISO8601DateFormatter().string(from: Date()))")
if let f = TestHarness.filter {
    print("filter: \(f)")
}
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
InfoPlistSyncTests.run()
ReleaseCoherenceTests.run()
MCPProtocolTests.run()
LocalizableCatalogTests.run()
HistorySearchTests.run()
DiskUsageScannerTests.run()
ConciergeToolsTests.run()
InstalledAppRegistryTests.run()
FleetChunkSwarmTests.run()
ConciergeBridgeTests.run()
InstallVerificationTests.run()
AppMoverTests.run()
ZipInstallerTests.run()
SwarmCoordinatorTests.run()
SwarmContentCacheTests.run()
SwarmParticipantTests.run()
AutoUpdateSchedulerTests.run()
SwarmHooksTests.run()

// v0.44: ConciergeTests, DownloadScheduleTests, LicenseValidatorTests,
// RecipeParserTests moved with their sources to the private
// Splynek/splynek-pro repo.

TestHarness.finish()
