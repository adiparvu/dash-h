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
import AppIntents
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
        case .accessoryRectangular:
            accessoryRectangularBody
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

    // MARK: Watch Face / Lock Screen — accessoryRectangular

    private var accessoryRectangularBody: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text("\(Int(entry.snapshot.propertyHealth * 100))% healthy")
                    .font(.headline.weight(.semibold))
            } icon: {
                Image(systemName: "globe.americas.fill").foregroundStyle(.prvioHorizon)
            }
            Text(entry.snapshot.topInsight)
                .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 6) {
                if entry.snapshot.alerts > 0 {
                    Label("\(entry.snapshot.alerts)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundStyle(.red)
                }
                Label(String(format: "%.1f kWh", entry.snapshot.energyKwh), systemImage: "bolt.fill")
                    .font(.caption2).foregroundStyle(.yellow)
            }
        }
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

// MARK: - Per-Module Intent Widget

// Module choice enum used only in the widget extension so there's no cross-target dependency.
enum ModuleChoice: String, AppEnum, CaseIterable {
    case forest, orchard, pond, garden, greenhouse, home, agriculture

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Module")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .forest:      .init(title: "Forest"),
        .orchard:     .init(title: "Orchard"),
        .pond:        .init(title: "Pond"),
        .garden:      .init(title: "Garden"),
        .greenhouse:  .init(title: "Glass House"),
        .home:        .init(title: "Home"),
        .agriculture: .init(title: "Fields"),
    ]

    var displayName: String {
        Self.caseDisplayRepresentations[self]?.title.key ?? rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .forest:      return "tree.fill"
        case .orchard:     return "leaf.fill"
        case .pond:        return "drop.fill"
        case .garden:      return "sparkle"
        case .greenhouse:  return "thermometer.sun.fill"
        case .home:        return "house.fill"
        case .agriculture: return "chart.bar.fill"
        }
    }

    var tint: Color {
        switch self {
        case .forest:      return .domainForest
        case .orchard:     return .domainOrchard
        case .pond:        return .domainPond
        case .garden:      return .domainGarden
        case .greenhouse:  return .domainGreenhouse
        case .home:        return .domainHome
        case .agriculture: return .domainAgriculture
        }
    }
}

struct ModulePickerIntent: AppIntent, WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Module"
    static var description = IntentDescription("Select which property module to display.")

    @Parameter(title: "Module")
    var module: ModuleChoice

    init() {}
    init(module: ModuleChoice) { self.module = module }

    func perform() async throws -> some IntentResult { .result() }
}

// MARK: - Module Entry + Provider

struct ModuleEntry: TimelineEntry {
    let date: Date
    let snapshot: TwinSnapshot
    let module: ModuleChoice
}

struct ModuleProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ModuleEntry {
        ModuleEntry(date: .now, snapshot: .placeholder, module: .forest)
    }

    func snapshot(for configuration: ModulePickerIntent, in context: Context) async -> ModuleEntry {
        ModuleEntry(
            date: .now,
            snapshot: TwinSnapshotBridge.load() ?? .placeholder,
            module: configuration.module)
    }

    func timeline(for configuration: ModulePickerIntent, in context: Context) async -> Timeline<ModuleEntry> {
        let entry = ModuleEntry(
            date: .now,
            snapshot: TwinSnapshotBridge.load() ?? .placeholder,
            module: configuration.module)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900)))
    }
}

// MARK: - Module Widget View

struct ModuleWidgetView: View {
    var entry: ModuleEntry
    @Environment(\.widgetFamily) var family

    private var moduleHealth: Double {
        entry.snapshot.moduleHealth[entry.module.rawValue] ?? entry.snapshot.propertyHealth
    }

    private var statusText: String {
        moduleHealth >= 0.8 ? "Healthy" : moduleHealth >= 0.6 ? "Needs Attention" : "Critical"
    }

    var body: some View {
        switch family {
        case .systemSmall:  smallBody
        case .systemLarge:  largeBody
        default:            mediumBody
        }
    }

    private var smallBody: some View {
        VStack(spacing: 6) {
            Image(systemName: entry.module.icon)
                .font(.title2)
                .foregroundStyle(entry.module.tint)
            Text(entry.module.displayName)
                .font(.prvioCaption())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(moduleHealth * 100))").font(.prvioMetric())
                Text("%").font(.prvioCaption()).foregroundStyle(.secondary)
            }
            Text(statusText)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(moduleHealth.healthColor)
        }
        .padding(12)
        .containerBackground(Color.prvioDeep.gradient, for: .widget)
    }

    private var mediumBody: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                Gauge(value: moduleHealth, in: 0...1) {
                    Image(systemName: entry.module.icon)
                        .foregroundStyle(entry.module.tint)
                } currentValueLabel: {
                    Text("\(Int(moduleHealth * 100))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(moduleHealth.healthColor)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(entry.module.tint)
                .frame(width: 64, height: 64)

                Text(entry.module.displayName)
                    .font(.prvioCaption())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(statusText)
                    .font(.prvioLabel())
                    .foregroundStyle(moduleHealth.healthColor)
                Text(entry.snapshot.topInsight)
                    .font(.prvioCaption())
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Spacer(minLength: 0)
                Text(entry.date, style: .time)
                    .font(.prvioCaption())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .containerBackground(Color.prvioDeep.gradient, for: .widget)
    }

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(entry.module.displayName, systemImage: entry.module.icon)
                    .font(.prvioHeadline())
                    .foregroundStyle(entry.module.tint)
                Spacer()
                if entry.snapshot.alerts > 0 {
                    Text("\(entry.snapshot.alerts)!")
                        .font(.caption2.bold())
                        .padding(5)
                        .background(Circle().fill(.red))
                        .foregroundStyle(.white)
                }
            }

            Gauge(value: moduleHealth, in: 0...1) {
                EmptyView()
            } currentValueLabel: {
                Text("\(Int(moduleHealth * 100))%")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(moduleHealth.healthColor)
            } minimumValueLabel: {
                Text("0").font(.caption2).foregroundStyle(.tertiary)
            } maximumValueLabel: {
                Text("100").font(.caption2).foregroundStyle(.tertiary)
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(entry.module.tint)

            Text(statusText)
                .font(.prvioLabel())
                .foregroundStyle(moduleHealth.healthColor)

            Text(entry.snapshot.topInsight)
                .font(.prvioCaption())
                .foregroundStyle(.secondary)
                .lineLimit(4)

            Spacer(minLength: 0)

            HStack {
                Label(String(format: "%.1f kWh", entry.snapshot.energyKwh),
                      systemImage: "bolt.fill")
                    .font(.prvioCaption())
                    .foregroundStyle(.domainEnergy)
                Spacer()
                Text("Updated \(entry.date, style: .time)")
                    .font(.prvioCaption())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .containerBackground(Color.prvioDeep.gradient, for: .widget)
    }
}

// MARK: - Module Widget Configuration

struct ModuleWidget: Widget {
    let kind = "ModuleWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ModulePickerIntent.self, provider: ModuleProvider()) { entry in
            ModuleWidgetView(entry: entry)
        }
        .configurationDisplayName("Module Health")
        .description("Track health and insights for a specific property module.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
