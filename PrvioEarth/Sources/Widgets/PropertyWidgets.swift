//
//  PropertyWidgets.swift
//  PRVIO EARTH — Widget Extension
//
//  WidgetKit surface for the Home Screen, Lock Screen and StandBy. Shares
//  the same models/engines as the app via a read-only twin snapshot
//  written to the App Group. Glanceable, object-centric, Liquid Glass.
//
//  NOTE: This belongs to a Widget Extension target; the timeline provider
//  reads a lightweight snapshot rather than the full live engine.
//

import WidgetKit
import SwiftUI
import PrvioEarthCore   // design tokens (Color/Spacing/fonts) come from the shared framework

// MARK: - Snapshot model (shared via App Group)

public struct TwinSnapshot: Codable, Sendable {
    public var propertyHealth: Double
    public var alerts: Int
    public var topInsight: String
    public var energyKwh: Double
    public var capturedAt: Date

    public init(propertyHealth: Double, alerts: Int, topInsight: String, energyKwh: Double, capturedAt: Date = .now) {
        self.propertyHealth = propertyHealth; self.alerts = alerts
        self.topInsight = topInsight; self.energyKwh = energyKwh; self.capturedAt = capturedAt
    }

    public static let placeholder = TwinSnapshot(
        propertyHealth: 0.86, alerts: 2,
        topInsight: "Orchard soil moisture low", energyKwh: 32.6)
}

// MARK: - Timeline

struct PropertyEntry: TimelineEntry {
    let date: Date
    let snapshot: TwinSnapshot
}

struct PropertyProvider: TimelineProvider {
    func placeholder(in context: Context) -> PropertyEntry {
        PropertyEntry(date: .now, snapshot: .placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (PropertyEntry) -> Void) {
        completion(PropertyEntry(date: .now, snapshot: SnapshotStore.load() ?? .placeholder))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PropertyEntry>) -> Void) {
        let entry = PropertyEntry(date: .now, snapshot: SnapshotStore.load() ?? .placeholder)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }
}

/// Reads/writes the snapshot to the shared App Group container.
enum SnapshotStore {
    static let suite = "group.com.prvio.earth"
    static let key = "twin.snapshot"

    static func save(_ snapshot: TwinSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot),
              let defaults = UserDefaults(suiteName: suite) else { return }
        defaults.set(data, forKey: key)
    }
    static func load() -> TwinSnapshot? {
        guard let defaults = UserDefaults(suiteName: suite),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TwinSnapshot.self, from: data)
    }
}

// MARK: - Widget View

struct PropertyWidgetView: View {
    var entry: PropertyEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "globe.americas.fill").foregroundStyle(.prvioHorizon)
                Text("PRVIO").font(.prvioCaption())
                Spacer()
                if entry.snapshot.alerts > 0 {
                    Text("\(entry.snapshot.alerts)")
                        .font(.caption2.bold()).padding(5)
                        .background(Circle().fill(.red)).foregroundStyle(.white)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(entry.snapshot.propertyHealth * 100))").font(.prvioMetric())
                Text("% health").font(.prvioCaption()).foregroundStyle(.secondary)
            }
            if family != .systemSmall {
                Text(entry.snapshot.topInsight).font(.prvioCaption())
                    .foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Label("\(String(format: "%.1f", entry.snapshot.energyKwh)) kWh", systemImage: "bolt.fill")
                .font(.prvioCaption()).foregroundStyle(.domainEnergy)
        }
        .padding(12)
        .containerBackground(for: .widget) { Color.prvioDeep.gradient }
    }
}

struct PropertyWidget: Widget {
    let kind = "PropertyWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PropertyProvider()) { entry in
            PropertyWidgetView(entry: entry)
        }
        .configurationDisplayName("Property Health")
        .description("Live health, alerts and energy from your Digital Twin.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
