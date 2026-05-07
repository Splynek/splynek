// Copyright © 2026 Splynek. MIT.
//
// JobsView — per-Mac active jobs list.  Polls `/api/jobs` every 2s
// while visible, stops on disappear.  Each row shows progress + name.
//
// Phase 2 will turn this into a Live Activity provider — when a job
// is running, we start a Live Activity that mirrors to the Mac menu
// bar via macOS 26's Live-Activity passthrough.

#if canImport(SwiftUI)
import SwiftUI

struct JobsView: View {
    let mac: PairedMac
    @State private var jobs: [JobSummary] = []
    @State private var lastError: String?
    @State private var pollTimer: Timer?
    @State private var submitURL: String = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("URL to download", text: $submitURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Send") { Task { await submit() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(submitURL.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if jobs.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("No active downloads")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 24)
                        Spacer()
                    }
                }
            } else {
                Section("Active") {
                    ForEach(jobs) { job in
                        JobRow(job: job)
                    }
                }
            }

            if let lastError {
                Section {
                    Label(lastError, systemImage: "wifi.exclamationmark")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(mac.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
        .refreshable { await refresh() }
    }

    @MainActor
    private func submit() async {
        let raw = submitURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: raw) else { return }
        do {
            try await PairedMacClient(mac: mac).queue(url: url)
            submitURL = ""
            await refresh()
        } catch {
            lastError = "Submit failed: \(error.localizedDescription)"
        }
    }

    private func startPolling() {
        Task { await refresh() }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { await refresh() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    @MainActor
    private func refresh() async {
        do {
            jobs = try await PairedMacClient(mac: mac).jobs()
            lastError = nil
        } catch PairedMacClient.ClientError.unauthorised {
            lastError = "Token rejected — re-pair this Mac."
            stopPolling()
        } catch {
            lastError = "Can't reach \(mac.displayName) right now."
        }
    }
}

private struct JobRow: View {
    let job: JobSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(job.displayName)
                .font(.body)
                .lineLimit(1)
            if let frac = job.fractionComplete {
                ProgressView(value: frac)
            } else if job.phase == "queued" {
                Text("Queued").font(.caption).foregroundStyle(.secondary)
            } else if job.phase == "running" {
                ProgressView()
                    .progressViewStyle(.linear)
            }
            HStack {
                if let phase = job.phase {
                    Text(phase.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let bps = job.throughputBps, bps > 0 {
                    Text(formatThroughput(bps))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatThroughput(_ bps: Double) -> String {
        let units = ["B/s", "KiB/s", "MiB/s", "GiB/s"]
        var v = bps
        var i = 0
        while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
        return String(format: "%.1f %@", v, units[i])
    }
}
#endif
