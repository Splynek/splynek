// Copyright © 2026 Splynek. MIT.
//
// ShareSheetView — SwiftUI body for the Share Extension's sheet.
//
// Three states:
//   1. URL extracted + at least one paired Mac → main "Send to Mac" UI
//   2. URL extracted + no paired Mac → empty-state with link to app
//   3. No URL found → polite error
//
// The picker pre-selects the most-recently-seen Mac.  iOS share-sheet
// extensions are rendered as a tall pageSheet on iPhone, so the
// layout is intentionally vertical + tap-friendly (no Form, just
// VStack + buttons sized for thumbs).

#if canImport(SwiftUI)
import SwiftUI

struct ShareSheetView: View {
    let url: URL?
    let macs: [PairedMac]
    let onSend: (PairedMac, URL) -> Void
    let onCancel: () -> Void

    @State private var pickedUUID: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if let url {
                    URLPreviewCard(url: url)
                    Divider()
                    if macs.isEmpty {
                        emptyMacs
                    } else {
                        macPicker
                        Spacer()
                        sendButton(target: url)
                    }
                } else {
                    noURLState
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Send to Splynek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear {
                pickedUUID = macs.sorted { $0.lastSeen > $1.lastSeen }.first?.uuid
            }
        }
    }

    @ViewBuilder
    private var macPicker: some View {
        Text("Send to")
            .font(.headline)
        ForEach(macs) { mac in
            Button {
                pickedUUID = mac.uuid
            } label: {
                HStack {
                    Image(systemName: pickedUUID == mac.uuid
                          ? "checkmark.circle.fill"
                          : "circle")
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mac.displayName)
                            .foregroundStyle(.primary)
                        Text("Last seen \(RelativeDateTimeFormatter().localizedString(for: mac.lastSeen, relativeTo: .now))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func sendButton(target: URL) -> some View {
        Button {
            guard let uuid = pickedUUID, let mac = macs.first(where: { $0.uuid == uuid }) else { return }
            onSend(mac, target)
        } label: {
            Text("Send")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(pickedUUID == nil)
    }

    @ViewBuilder
    private var emptyMacs: some View {
        VStack(spacing: 12) {
            Image(systemName: "macbook.and.iphone")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Macs paired yet")
                .font(.headline)
            Text("Open Splynek Companion to pair your Mac, then come back here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var noURLState: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.diamond")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Couldn't find a URL to share")
                .font(.headline)
            Text("This extension works on URL-shaped content — articles, video pages, file links, etc.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct URLPreviewCard: View {
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(url.host ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(url.absoluteString)
                .font(.body.monospaced())
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
#endif
