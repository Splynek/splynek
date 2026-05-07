// Copyright © 2026 Splynek. MIT.
//
// PairingSheet — the "add a Mac" flow.  Three required fields:
//
//   1. Display name  (defaults to the Bonjour TXT name if discovered)
//   2. Host          (IP or hostname, e.g. "macbook.local")
//   3. Token         (pasted from the Mac's Settings > Sharing tab)
//
// Once filled in, we hit `/splynek/v1/status` to confirm reachability,
// then save the record.  All-in-one flow; no multi-step wizard for a
// 3-field form.

#if canImport(SwiftUI)
import SwiftUI

struct PairingSheet: View {
    var onPaired: (PairedMac) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = "My Mac"
    @State private var host: String = ""
    @State private var port: String = "0"
    @State private var token: String = ""
    @State private var probing = false
    @State private var lastError: String?
    @State private var showingScanner = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan QR from Mac", systemImage: "qrcode.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                    Text("Faster — open Splynek on your Mac, go to Settings → Web dashboard, and aim at the iPhone-pair QR.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Mac") {
                    TextField("Name (e.g. Paulo's MacBook)", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    TextField("Host (e.g. mac.local or 192.168.1.20)", text: $host)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port (default 18280)", text: $port)
                        .keyboardType(.numberPad)
                }
                Section("Token") {
                    SecureField("Paste from Mac → Settings → Sharing", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Open Splynek on your Mac, go to Settings → Sharing, and tap the copy-token button.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let lastError {
                    Section {
                        Label(lastError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Pair a Mac")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(probing ? "Pairing…" : "Pair") { Task { await attempt() } }
                        .disabled(!canSubmit || probing)
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                QRScannerView(
                    onPaired: { components in
                        // Pre-fill the form from the scanned QR.
                        host = components.host
                        port = String(components.port)
                        token = components.token
                        if let n = components.name, !n.isEmpty {
                            displayName = n
                        }
                        showingScanner = false
                        // Auto-submit — the user has already
                        // expressed intent by scanning.  If the Mac
                        // is unreachable the form re-appears with
                        // the fields populated for retry.
                        Task { await attempt() }
                    },
                    onCancel: { showingScanner = false }
                )
            }
        }
    }

    private var canSubmit: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty
            && !token.trimmingCharacters(in: .whitespaces).isEmpty
            && (Int(port) ?? 0) > 0
    }

    @MainActor
    private func attempt() async {
        probing = true
        defer { probing = false }
        lastError = nil
        let candidate = PairedMac(
            uuid: UUID().uuidString,  // overwritten on first jobs poll
            displayName: displayName.isEmpty ? "My Mac" : displayName,
            lastKnownHost: host.trimmingCharacters(in: .whitespaces),
            lastKnownPort: Int(port) ?? 18280,
            token: token.trimmingCharacters(in: .whitespaces),
            lastSeen: Date()
        )
        let client = PairedMacClient(mac: candidate)
        do {
            _ = try await client.ping()
            onPaired(candidate)
            dismiss()
        } catch PairedMacClient.ClientError.unauthorised {
            lastError = "Token rejected by the Mac. Double-check it's the current token from Settings → Sharing."
        } catch PairedMacClient.ClientError.notReachable, PairedMacClient.ClientError.http {
            lastError = "Couldn't reach the Mac at \(host):\(port). Make sure Splynek is running and you're on the same Wi-Fi."
        } catch {
            lastError = "Pairing failed: \(error.localizedDescription)"
        }
    }
}
#endif
