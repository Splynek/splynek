// Copyright © 2026 Splynek. MIT.
//
// SplynekWatchComplicationsBundle — Sprint 3 (2026-05-10).
//
// Watch face complications powered by the Sovereignty / Trust
// Watcher / active-downloads summary endpoints on the user's
// default Mac.  Same data path the iOS Widget uses (Sprint 1
// `9dca20c`); the watch displays a tighter subset.
//
// Complication families shipped:
//   • accessoryCircular  — Sovereignty score as a hero number,
//                          tinted by the score's traffic-light
//                          band (green / yellow / red).
//   • accessoryRectangular — Sovereignty score + active-downloads
//                            count, two lines.
//   • accessoryInline    — single-line "Splynek 73 · 2 active"
//                          for the watch face's text-only slot.
//
// Refresh: 30-min `policy: .after` budget.  Watch complications
// are stricter than iPhone widgets — Apple meters refresh credit
// per app per day; over-aggressive refresh demotes the watch face
// to "stale" rendering.
//
// Privacy posture: same as the iOS Widget — talks only to the
// user's paired Mac via the existing token-gated REST endpoints.

#if canImport(WidgetKit) && canImport(SwiftUI) && os(watchOS)
import WidgetKit
import SwiftUI

@main
struct SplynekWatchComplicationsBundle: WidgetBundle {
    var body: some Widget {
        SplynekSovereigntyComplication()
    }
}

// MARK: - Entry

@available(watchOS 10.0, *)
struct SplynekSovereigntyEntry: TimelineEntry {
    let date: Date
    let macName: String?
    let sovereigntyScore: Int?
    let activeDownloads: Int?

    static let placeholder = SplynekSovereigntyEntry(
        date: Date(), macName: "Mac",
        sovereigntyScore: 73, activeDownloads: 2
    )
    static let unpaired = SplynekSovereigntyEntry(
        date: Date(), macName: nil,
        sovereigntyScore: nil, activeDownloads: nil
    )
}

// MARK: - Provider

@available(watchOS 10.0, *)
struct SplynekSovereigntyProvider: TimelineProvider {

    func placeholder(in context: Context) -> SplynekSovereigntyEntry {
        .placeholder
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (SplynekSovereigntyEntry) -> Void) {
        Task {
            completion(await fetch())
        }
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<SplynekSovereigntyEntry>) -> Void) {
        Task {
            let entry = await fetch()
            // 30-minute refresh — Apple's Watch complication budget
            // recommendation for "occasionally interesting" data.
            let next = Date().addingTimeInterval(30 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func fetch() async -> SplynekSovereigntyEntry {
        guard let store = PairedMacStore() else { return .unpaired }
        let macs = store.all().sorted(by: { $0.lastSeen > $1.lastSeen })
        guard let mac = macs.first else { return .unpaired }
        let client = PairedMacClient(mac: mac)
        async let sov = try? client.sovereigntySummary()
        async let jobs = try? client.jobs()
        let sovValue = await sov
        let jobsValue = await jobs
        let active = jobsValue?.filter { ($0.phase ?? "") == "running" }.count
        return SplynekSovereigntyEntry(
            date: Date(),
            macName: mac.displayName,
            sovereigntyScore: sovValue?.score,
            activeDownloads: active
        )
    }
}

// MARK: - Views

@available(watchOS 10.0, *)
struct CircularComplicationView: View {
    let entry: SplynekSovereigntyEntry
    var body: some View {
        if let score = entry.sovereigntyScore {
            Gauge(value: Double(score), in: 0...100) {
                Text("Sov.")
            } currentValueLabel: {
                Text("\(score)")
                    .font(.system(.caption, design: .rounded))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(scoreTint(score))
        } else {
            Image(systemName: "questionmark")
        }
    }
}

@available(watchOS 10.0, *)
struct RectangularComplicationView: View {
    let entry: SplynekSovereigntyEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "shield.lefthalf.filled")
                if let score = entry.sovereigntyScore {
                    Text("Sovereignty: \(score)")
                        .foregroundStyle(scoreTint(score))
                } else {
                    Text("Sovereignty: —")
                }
            }
            .font(.caption.weight(.semibold))
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                Text(activeLabel(entry.activeDownloads))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

@available(watchOS 10.0, *)
struct InlineComplicationView: View {
    let entry: SplynekSovereigntyEntry
    var body: some View {
        if let score = entry.sovereigntyScore {
            Text("Splynek \(score)\(entry.activeDownloads.map { " · \($0) active" } ?? "")")
        } else {
            Text("Splynek —")
        }
    }
}

@available(watchOS 10.0, *)
fileprivate func scoreTint(_ score: Int) -> Color {
    switch score {
    case 80...:    return .green
    case 50..<80:  return .yellow
    default:       return .red
    }
}

@available(watchOS 10.0, *)
fileprivate func activeLabel(_ active: Int?) -> String {
    guard let active else { return "— active" }
    switch active {
    case 0:  return "Idle"
    case 1:  return "1 active"
    default: return "\(active) active"
    }
}

// MARK: - Widget

@available(watchOS 10.0, *)
struct SplynekSovereigntyComplication: Widget {
    let kind: String = "SplynekSovereigntyComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind,
                            provider: SplynekSovereigntyProvider()) { entry in
            view(for: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Splynek")
        .description("Sovereignty score + active downloads on your default Mac.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }

    @ViewBuilder
    private func view(for entry: SplynekSovereigntyEntry) -> some View {
        FamilyReader(entry: entry)
    }
}

@available(watchOS 10.0, *)
private struct FamilyReader: View {
    @Environment(\.widgetFamily) var family
    let entry: SplynekSovereigntyEntry
    var body: some View {
        switch family {
        case .accessoryCircular:    CircularComplicationView(entry: entry)
        case .accessoryRectangular: RectangularComplicationView(entry: entry)
        case .accessoryInline:      InlineComplicationView(entry: entry)
        default:                    InlineComplicationView(entry: entry)
        }
    }
}

#endif
