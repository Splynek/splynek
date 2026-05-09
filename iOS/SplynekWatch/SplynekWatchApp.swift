// Copyright © 2026 Splynek. MIT.
//
// SplynekWatchApp — watchOS app skeleton for the Sovereignty +
// Trust at-a-glance + tap-to-pause/resume Sprint 2 part-2 must-have.
//
// Pairing model: the Watch reads from the same App Group plist
// the iPhone writes to.  When the user pairs a Mac on the
// iPhone, that record is shared via App Group and the Watch
// picks it up automatically.  No separate pairing flow.
//
// Status (this commit): minimal viable.  Two action buttons
// (Pause all / Resume all) + a status row showing the default
// Mac name + Sovereignty score.  Tap an action → calls the same
// PairedMacClient methods the iOS App Intents use.

#if canImport(SwiftUI) && os(watchOS)
import SwiftUI
import WatchKit

@main
struct SplynekWatchApp: App {
    var body: some Scene {
        WindowGroup {
            SplynekWatchContentView()
        }
    }
}

struct SplynekWatchContentView: View {
    @State private var defaultMac: PairedMac?
    @State private var sovereigntyScore: Int?
    @State private var statusMessage: String = ""
    @State private var isWorking: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let mac = defaultMac {
                    pairedHeader(mac)
                    actionButtons
                    if let score = sovereigntyScore {
                        sovereigntyRow(score)
                    }
                    statusFooter
                } else {
                    unpairedBody
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Splynek")
        .task { await refresh() }
    }

    // MARK: Sections

    @ViewBuilder
    private func pairedHeader(_ mac: PairedMac) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(mac.displayName)
                .font(.headline)
                .lineLimit(1)
            Text(mac.lastSeen.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                Task { await call(.pauseAll) }
            } label: {
                Label("Pause all", systemImage: "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.orange)
            .disabled(isWorking || defaultMac == nil)

            Button {
                Task { await call(.resumeAll) }
            } label: {
                Label("Resume all", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.green)
            .disabled(isWorking || defaultMac == nil)
        }
    }

    @ViewBuilder
    private func sovereigntyRow(_ score: Int) -> some View {
        HStack {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(scoreColor(score))
            Text("Sovereignty")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(score)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(scoreColor(score))
                .monospacedDigit()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.1))
        )
    }

    @ViewBuilder
    private var statusFooter: some View {
        if !statusMessage.isEmpty {
            Text(statusMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var unpairedBody: some View {
        VStack(spacing: 8) {
            Image(systemName: "macbook.and.iphone")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("No Mac paired.")
                .font(.headline)
            Text("Pair one on your iPhone Splynek Companion app.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
    }

    // MARK: Actions

    private enum Action { case pauseAll, resumeAll }

    private func call(_ action: Action) async {
        guard let mac = defaultMac else { return }
        isWorking = true
        defer { isWorking = false }
        let client = PairedMacClient(mac: mac)
        do {
            switch action {
            case .pauseAll:  try await client.pauseAll()
            case .resumeAll: try await client.resumeAll()
            }
            statusMessage = action == .pauseAll
                ? "Paused on \(mac.displayName)."
                : "Resumed on \(mac.displayName)."
            // Strong haptic so the user feels the action confirmed
            // without looking at the screen.
            WKInterfaceDevice.current().play(.success)
        } catch {
            statusMessage = "Couldn't reach \(mac.displayName)."
            WKInterfaceDevice.current().play(.failure)
        }
    }

    private func refresh() async {
        guard let store = PairedMacStore() else {
            statusMessage = "App Group unavailable."
            return
        }
        let macs = store.all().sorted(by: { $0.lastSeen > $1.lastSeen })
        defaultMac = macs.first
        guard let mac = defaultMac else { return }
        let client = PairedMacClient(mac: mac)
        // Best-effort sovereignty fetch; nil leaves the row hidden.
        sovereigntyScore = (try? await client.sovereigntySummary().score)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...:    return .green
        case 50..<80:  return .yellow
        default:       return .red
        }
    }
}

#endif
