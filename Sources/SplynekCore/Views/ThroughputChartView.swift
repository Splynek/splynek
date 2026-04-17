import SwiftUI
import Charts

/// Pretty per-lane throughput chart. One line per lane, gradient area fill
/// underneath the aggregate. Uses the accent palette so it adapts to light
/// and dark appearance.
struct ThroughputChartView: View {
    let lanes: [LaneStats]

    var body: some View {
        Chart {
            // Aggregate: sum across lanes, drawn as area fill.
            if let summed = aggregated {
                ForEach(Array(summed.enumerated()), id: \.offset) { idx, bps in
                    AreaMark(
                        x: .value("t", idx),
                        y: .value("bytes/s", bps)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.25), .accentColor.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)
                }
            }
            // Per-lane lines on top of the aggregate fill.
            ForEach(lanes) { lane in
                ForEach(Array(lane.history.enumerated()), id: \.offset) { idx, bps in
                    LineMark(
                        x: .value("t", idx),
                        y: .value("bytes/s", bps)
                    )
                    .foregroundStyle(by: .value("lane", lane.interface.name))
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                AxisValueLabel {
                    if let n = value.as(Double.self) {
                        Text(formatRate(n))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
        .chartLegend(position: .bottom, alignment: .leading, spacing: 6)
        .frame(height: 140)
    }

    /// Sum per-sample throughput across lanes (aligned to the shortest
    /// history so we don't stretch).
    private var aggregated: [Double]? {
        let histories = lanes.map(\.history)
        guard let minLen = histories.map(\.count).min(), minLen > 0 else { return nil }
        var sum = Array(repeating: 0.0, count: minLen)
        for h in histories {
            let window = h.suffix(minLen)
            for (i, v) in window.enumerated() { sum[i] += v }
        }
        return sum
    }
}
