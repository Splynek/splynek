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
SwarmAnnouncementObserverTests.run()
EngineExternalIngestTests.run()
PkgInstallerTests.run()
PublisherPatternTests.run()
PrivilegedHelperClientTests.run()
ConciergeTranscriptStoreTests.run()
PathMonitorObserverTests.run()
MirrorManifestTests.run()
SovereigntyCSVExportTests.run()
TrustExportTests.run()
TrustWatcherTests.run()
TrustWatchAlertRecordTests.run()
SovereigntyMigratePlanTests.run()
SovereigntyMigrateReviewListTests.run()
ConciergeSequenceTests.run()
ConciergeSequenceRunnerTests.run()
ConciergeMigrateDigestTests.run()
EngagementCountersTests.run()
APITokenTests.run()
GeoFencePolicyTests.run()
AtomicFlagTests.run()
EngineRestartLoopTests.run()
DownloadJobResumeTests.run()
YtDlpProbeTests.run()
YtDlpRunnerTests.run()
DownloadReceiptTests.run()
HLSManifestTests.run()
HLSRingBufferTests.run()
HLSProxyServerTests.run()
BondedFetcherTests.run()
DASHManifestTests.run()

// S4 iOS Companion (2026-05-07): pure-Swift logic from the iOS
// app + Share Extension's shared core (PairedMac, ShareExtractor,
// SplynekTXTRecord, PairedMacStore in-memory mode).  UIKit / SwiftUI
// surfaces are not tested here — they live under iOS/SplynekCompanion
// + iOS/SplynekShareExtension and require the iOS Simulator.
CompanionShareExtractorTests.run()
CompanionBonjourTests.run()
CompanionStoreTests.run()
// S4 phase 2 (2026-05-07): Live Activity coordinator + QR-pair URL.
// Pure transitions; ActivityKit / AVFoundation lives only in the
// iOS-only LiveActivityDriver + QRScannerView.
CompanionLiveActivityTests.run()
CompanionPairURLTests.run()
// S4 phase 3 (2026-05-07): CloudKit over-cellular relay.  Pure
// transitions + record encode/decode; CKContainer/database calls
// live in CloudKitRelaySubmitter / CloudKitRelayReceiver and are
// exercised on-device only.
CompanionRelayPolicyTests.run()
CompanionCloudKitRecordTests.run()
// S4 polish (2026-05-07): per-Mac health classifier driving the
// iOS Settings tab's status badges.
CompanionPairingHealthTests.run()
// 2026-05-07 product expansion phase 1: deliveryKind classifier
// driving Sovereignty UI badges.
DeliveryKindTests.run()
// Phase 2: AppPricing schema + SavingsSummary computation.
SavingsTests.run()
// Phase 3: Updates tab — AppUpdateInfo + UpdateSourceResolver +
// SparkleAppcast pure-Swift parser.
AppUpdateTests.run()
// Phase 3 follow-up (2026-05-07): the three additional resolvers
// for GitHub Releases / Homebrew / publisher RSS.
UpdateResolverTests.run()

// 2026-05-08 audit pass: pure-logic coverage for the changes shipped
// during the design/UX revolution session — InstallPreflight,
// AppPricing tier annualisation, DownloadHistory remove/clearAll, and
// the dedupe-relevant edge cases of AppUpdateInfo.isNewer.
HardeningTests.run()

// v0.44: ConciergeTests, DownloadScheduleTests, LicenseValidatorTests,
// RecipeParserTests moved with their sources to the private
// Splynek/splynek-pro repo.

TestHarness.finish()
