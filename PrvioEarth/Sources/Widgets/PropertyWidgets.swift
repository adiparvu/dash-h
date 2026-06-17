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
import PrvioEarthCore   // TwinSnapshot, TwinSnapshotBridge, design tokens

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
        completion(PropertyEntry(date: .now, snapshot: TwinSnapshotBridge.load() ?? .placeholder))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PropertyEntry>) -> Void) {
        let entry = PropertyEntry(date: .now, snapshot: TwinSnapshotBridge.load() ?? .placeholder)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
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
        .containerBackground(Color.prvioDeep.gradient, for: .widget)
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
