// Copyright © 2026 Splynek. MIT.
//
// SubmitURLView — type-or-paste fallback when the user is in the
// companion app directly rather than coming through the Share
// Extension.  Lets them pick a paired Mac + queue a URL.

#if canImport(SwiftUI)
import SwiftUI

struct SubmitURLView: View {
    @State private var url: String = ""
    @State private var paired: [PairedMac] = []
    @State private var pickedUUID: String?
    @State private var lastResult: String?
    @State private var sending = false

    private var store: PairedMacStore? { PairedMacStore() }

    var body: some View {
        Form {
            Section("URL") {
                TextField("https://…", text: $url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Paste from clipboard") {
                    if let s = UIPasteboard.general.string {
                        url = s
                    }
                }
                .font(.caption)
            }

            Section("Send to") {
                if paired.isEmpty {
                    Text("No Macs paired. Switch to the Macs tab to pair one first.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Mac", selection: $pickedUUID) {
                        ForEach(paired) { m in
                            Text(m.displayName).tag(Optional(m.uuid))
                        }
                    }
                }
            }

            if let lastResult {
                Section { Text(lastResult).foregroundStyle(.secondary) }
            }

            Section {
                Button(sending ? "Sending…" : "Queue download") {
                    Task { await send() }
                }
                .disabled(!canSend || sending)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Submit URL")
        .onAppear { refresh() }
    }

    private var canSend: Bool {
        !url.trimmingCharacters(in: .whitespaces).isEmpty
            && pickedUUID != nil
            && !paired.isEmpty
    }

    private func refresh() {
        paired = store?.all() ?? []
        if pickedUUID == nil {
            pickedUUID = paired.first?.uuid
        }
    }

    @MainActor
    private func send() async {
        sending = true
        defer { sending = false }
        guard let uuid = pickedUUID, let mac = paired.first(where: { $0.uuid == uuid }),
              let target = URL(string: url.trimmingCharacters(in: .whitespaces))
        else { return }
        do {
            try await PairedMacClient(mac: mac).queue(url: target)
            lastResult = "Queued on \(mac.displayName)."
            url = ""
        } catch {
            lastResult = "Couldn't reach \(mac.displayName): \(error.localizedDescription)"
        }
    }
}
#endif
