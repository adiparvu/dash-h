//
//  WatchTwinView.swift
//  PRVIO EARTH — watchOS Companion
//
//  Main view for the Apple Watch companion app. Surfaces overall property
//  health, top insight and per-module health scores in a glanceable format
//  appropriate for the small screen. Data arrives via WatchSessionBridge
//  for real-time updates; if no session data is present the last snapshot
//  from the shared App Group is used as a fallback.
//
//  Also contains the WidgetKit complication provider and views. To register
//  them, add WatchHealthComplication() to your Watch app's WidgetBundle.
//

#if os(watchOS)
import SwiftUI
import WidgetKit

// MARK: - Companion App View

public struct WatchTwinView: View {
    private let bridge = WatchSessionBridge.shared

    public init() {}

    public var body: some View {
        Group {
            if let snap = bridge.latestSnapshot ?? TwinSnapshotBridge.load() {
                liveView(snap)
            } else {
                connectingView
            }
        }
        .navigationTitle("PRVIO")
    }

    private func liveView(_ snap: TwinSnapshot) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                healthGauge(snap)
                Text(snap.topInsight)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                moduleGrid(snap)
                if snap.alerts > 0 {
                    Label("\(snap.alerts) alert\(snap.alerts == 1 ? "" : "s")",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(snap.capturedAt, style: .time)
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }
            .padding()
        }
    }

    private var connectingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Connecting…").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func healthGauge(_ snap: TwinSnapshot) -> some View {
        Gauge(value: snap.propertyHealth, in: 0...1) {
            Image(systemName: "globe.americas.fill")
        } currentValueLabel: {
            Text("\(Int(snap.propertyHealth * 100))")
                .font(.system(size: 20, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(.blue)
        .frame(width: 84, height: 84)
    }

    private func moduleGrid(_ snap: TwinSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(snap.moduleHealth.sorted(by: { $0.key < $1.key }), id: \.key) { key, score in
                WatchModuleCell(name: key, score: score)
            }
        }
    }
}

private struct WatchModuleCell: View {
    var name: String
    var score: Double

    private var dotColor: Color {
        score >= 0.8 ? .green : score >= 0.5 ? .yellow : .red
    }

    var body: some View {
        VStack(spacing: 3) {
            Circle().fill(dotColor).frame(width: 8, height: 8)
            Text(name.capitalized).font(.system(size: 9)).lineLimit(1)
            Text("\(Int(score * 100))%")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.15)))
    }
}

// MARK: - Complication Timeline Provider

struct WatchHealthEntry: TimelineEntry {
    let date: Date
    let snapshot: TwinSnapshot
}

struct WatchHealthProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchHealthEntry {
        WatchHealthEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchHealthEntry) -> Void) {
        completion(WatchHealthEntry(date: .now, snapshot: TwinSnapshotBridge.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchHealthEntry>) -> Void) {
        let snap = TwinSnapshotBridge.load() ?? .placeholder
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [WatchHealthEntry(date: .now, snapshot: snap)], policy: .after(next)))
    }
}

// MARK: - Complication Entry View (family-adaptive)

struct WatchComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: WatchHealthEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.snapshot.propertyHealth, in: 0...1) {
                Image(systemName: "globe.americas.fill")
            } currentValueLabel: {
                Text("\(Int(entry.snapshot.propertyHealth * 100))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text("\(Int(entry.snapshot.propertyHealth * 100))% healthy")
                        .font(.headline.weight(.semibold))
                } icon: {
                    Image(systemName: "globe.americas.fill")
                }
                Text(entry.snapshot.topInsight)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        case .accessoryInline:
            Label("Property \(Int(entry.snapshot.propertyHealth * 100))%",
                  systemImage: "globe.americas.fill")
        case .accessoryCorner:
            Gauge(value: entry.snapshot.propertyHealth, in: 0...1) {
                Image(systemName: "globe.americas.fill")
            }
            .gaugeStyle(.accessoryCircular)
            .widgetLabel {
                Text("PRVIO \(Int(entry.snapshot.propertyHealth * 100))%")
            }
        default:
            Gauge(value: entry.snapshot.propertyHealth, in: 0...1) {
                EmptyView()
            } currentValueLabel: {
                Text("\(Int(entry.snapshot.propertyHealth * 100))")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
    }
}

// MARK: - Widget Configuration (add to Watch app's WidgetBundle)

public struct WatchHealthComplication: Widget {
    public static let kind = "com.prvio.earth.watch.health"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: WatchHealthProvider()) { entry in
            WatchComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Property Health")
        .description("Live health score from your PRVIO Earth Digital Twin.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
#endif
