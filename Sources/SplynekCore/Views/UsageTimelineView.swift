import SwiftUI
import Charts

/// In-app rendering of the CSV data shipped in v0.37. One stacked
/// bar per day, series coloured by host (or Cellular/Cellular-over-
/// cap for the budget mode). The picker at the top switches between
/// the two datasets without re-mounting — cheap, the data's already
/// in memory.
struct UsageTimelineView: View {
    @ObservedObject var vm: SplynekViewModel

    enum Mode: String, CaseIterable, Hashable {
        case host     = "Host"
        case cellular = "Cellular"
    }

    @State private var mode: Mode = .host
    /// Window in days. 14 is the default — wide enough to see a
    /// weekly pattern, narrow enough to fit comfortably in the
    /// History pane.
    @State private var windowDays: Int = 14

    var body: some View {
        TitledCard(
            title: "Usage timeline",
            systemImage: "chart.bar.xaxis",
            accessory: AnyView(accessoryControls)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if points.isEmpty {
                    EmptyStateView(
                        systemImage: "chart.bar.xaxis",
                        title: emptyTitle,
                        message: emptyMessage
                    )
                } else {
                    chart
                    footer
                }
            }
        }
    }

    // MARK: Chart

    @ViewBuilder
    private var chart: some View {
        Chart {
            ForEach(points) { pt in
                BarMark(
                    x: .value("Date", shortDate(pt.date)),
                    y: .value("Bytes", pt.bytes)
                )
                .foregroundStyle(by: .value("Series", pt.series))
                .opacity(pt.isToday ? 1.0 : 0.78)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                AxisValueLabel {
                    if let n = value.as(Double.self) {
                        Text(formatBytes(Int64(n))).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(windowDays, 7))) { value in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.04))
                AxisValueLabel {
                    if let s = value.as(String.self) {
                        Text(s).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading, spacing: 6)
        .frame(height: 200)
    }

    // MARK: Controls

    private var accessoryControls: some View {
        HStack(spacing: 6) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 140)

            Button {
                switch mode {
                case .host:     vm.exportHostUsageCSV()
                case .cellular: vm.exportCellularBudgetCSV()
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)
            .help("Export the full timeline as CSV.")
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(summary)
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.tail)
            Spacer()
            Menu("\(windowDays) days") {
                ForEach([7, 14, 30, 60, 90], id: \.self) { n in
                    Button("\(n) days") { windowDays = n }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: Derived

    private var points: [UsageTimelinePoint] {
        switch mode {
        case .host:
            return UsageTimeline.hostData(
                today: HostUsage.load(),
                history: HostUsage.loadHistory(),
                lastNDays: windowDays
            )
        case .cellular:
            return UsageTimeline.cellularData(
                today: CellularBudget.load(),
                history: CellularBudget.loadHistory(),
                lastNDays: windowDays
            )
        }
    }

    private var summary: String {
        guard !points.isEmpty else { return "" }
        let total = points.reduce(Int64(0)) { $0 + $1.bytes }
        let dayCount = Set(points.map(\.date)).count
        return "\(formatBytes(total)) across \(dayCount) day\(dayCount == 1 ? "" : "s")"
    }

    private var emptyTitle: String {
        switch mode {
        case .host:     return "No host activity"
        case .cellular: return "No cellular activity"
        }
    }

    private var emptyMessage: String {
        switch mode {
        case .host:     return "Once a download runs, per-host totals show up here. Historical days roll in after midnight."
        case .cellular: return "Cellular totals appear once a download uses a cellular interface. Historical days roll in after midnight."
        }
    }

    /// Compress `yyyy-MM-dd` to `MM-dd` for axis labels so the chart
    /// has breathing room. `"today"` passes through.
    private func shortDate(_ iso: String) -> String {
        guard iso.count == 10 else { return iso }
        let from = iso.index(iso.startIndex, offsetBy: 5)
        return String(iso[from...])
    }
}
