//
//  PropertyWidgets.swift
//  PRVIO EARTH — Widget Extension
//
//  WidgetKit surface for the Home Screen, Lock Screen, StandBy and Watch
//  face complications. Shares models via the App Group snapshot written by
//  the live engine.  Glanceable, object-centric, Liquid Glass.
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

// MARK: - Widget Views

struct PropertyWidgetView: View {
    var entry: PropertyEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularBody
        case .accessoryInline:
            accessoryInlineBody
        case .systemExtraLarge:
            extraLargeBody
        case .systemLarge:
            largeBody
        default:
            regularBody
        }
    }

    // MARK: Home Screen — small/medium

    private var regularBody: some View {
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

    // MARK: Home Screen — large

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("PRVIO EARTH", systemImage: "globe.americas.fill")
                .font(.prvioCaption()).foregroundStyle(.prvioHorizon)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(entry.snapshot.propertyHealth * 100))").font(.prvioMetric())
                Text("% health").font(.prvioCaption()).foregroundStyle(.secondary)
            }

            Text(entry.snapshot.topInsight)
                .font(.prvioLabel()).foregroundStyle(.secondary).lineLimit(4)

            Spacer()

            HStack(spacing: 16) {
                metricPill("\(String(format: "%.1f", entry.snapshot.energyKwh)) kWh",
                           icon: "bolt.fill", tint: .domainEnergy)
                if entry.snapshot.alerts > 0 {
                    metricPill("\(entry.snapshot.alerts) alerts",
                               icon: "exclamationmark.triangle.fill", tint: .healthCritical)
                }
            }

            Text(entry.date, style: .time)
                .font(.prvioCaption()).foregroundStyle(.tertiary)
        }
        .padding(16)
        .containerBackground(Color.prvioDeep.gradient, for: .widget)
    }

    // MARK: StandBy / systemExtraLarge

    private static let standByModules = ["forest", "orchard", "pond", "home", "agriculture"]

    private var extraLargeBody: some View {
        HStack(alignment: .top, spacing: 32) {
            // Left: overall health + top insight
            VStack(alignment: .leading, spacing: 12) {
                Label("PRVIO EARTH", systemImage: "globe.americas.fill")
                    .font(.prvioCaption()).foregroundStyle(.prvioHorizon)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(entry.snapshot.propertyHealth * 100))").font(.prvioMetric())
                    Text("% healthy").font(.prvioHeadline()).foregroundStyle(.secondary)
                }
                Text(entry.snapshot.topInsight)
                    .font(.prvioLabel()).foregroundStyle(.secondary).lineLimit(4)
                Spacer()
                Text("Updated \(entry.date, style: .time)")
                    .font(.prvioCaption()).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: per-module health breakdown
            VStack(alignment: .leading, spacing: 10) {
                Text("Modules").font(.prvioCaption()).foregroundStyle(.secondary)
                ForEach(Self.standByModules, id: \.self) { key in
                    let score = entry.snapshot.moduleHealth[key] ?? 1
                    HStack(spacing: 10) {
                        Text(key.capitalized)
                            .font(.prvioCaption())
                            .foregroundStyle(.secondary)
                            .frame(width: 68, alignment: .leading)
                        Text("\(Int(score * 100))%")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(score.healthColor)
                    }
                }
                Spacer(minLength: 0)
                metricPill(
                    "\(String(format: "%.1f", entry.snapshot.energyKwh)) kWh",
                    icon: "bolt.fill", tint: .domainEnergy)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .containerBackground(Color.prvioDeep.gradient, for: .widget)
    }

    // MARK: Lock Screen / accessoryCircular

    private var accessoryCircularBody: some View {
        Gauge(value: entry.snapshot.propertyHealth, in: 0...1) {
            Image(systemName: "globe.americas.fill").foregroundStyle(.prvioHorizon)
        } currentValueLabel: {
            Text("\(Int(entry.snapshot.propertyHealth * 100))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(.prvioHorizon)
    }

    // MARK: Lock Screen / accessoryInline

    private var accessoryInlineBody: some View {
        let alertSuffix = entry.snapshot.alerts > 0 ? " · \(entry.snapshot.alerts)!" : ""
        return Label(
            "\(Int(entry.snapshot.propertyHealth * 100))%\(alertSuffix)",
            systemImage: "globe.americas.fill")
    }

    // MARK: Helpers

    private func metricPill(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.prvioLabel())
            .foregroundStyle(tint)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Widget Configuration

struct PropertyWidget: Widget {
    let kind = "PropertyWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PropertyProvider()) { entry in
            PropertyWidgetView(entry: entry)
        }
        .configurationDisplayName("Property Health")
        .description("Live health, alerts and energy from your Digital Twin.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
            .accessoryCircular, .accessoryInline, .accessoryRectangular,
        ])
    }
}
