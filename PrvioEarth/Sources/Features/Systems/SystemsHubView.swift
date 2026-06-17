//
//  SystemsHubView.swift
//  PRVIO EARTH
//
//  A glanceable Liquid Glass hub over the twin for the cross-cutting
//  systems — Energy, Weather, Water, Security — plus Automation and the
//  remaining Smart modules (Garden, Greenhouse). These are computed views
//  over the same entities via PropertyAnalytics, never separate dashboards.
//  Reached from the map's top bar; tapping a system focuses the map.
//

import SwiftUI

public struct SystemsHubView: View {
    var twin: DigitalTwinEngine
    var weatherEngine: WeatherEngine?
    var onOpenAutomation: () -> Void
    var onOpenCamera: () -> Void
    var onOpenDrone: () -> Void
    var onOpenEditor: () -> Void
    var onOpenSettings: () -> Void
    var onFocusModule: (PropertyModule) -> Void

    public init(twin: DigitalTwinEngine,
                weatherEngine: WeatherEngine? = nil,
                onOpenAutomation: @escaping () -> Void,
                onOpenCamera: @escaping () -> Void = {},
                onOpenDrone: @escaping () -> Void = {},
                onOpenEditor: @escaping () -> Void = {},
                onOpenSettings: @escaping () -> Void = {},
                onFocusModule: @escaping (PropertyModule) -> Void) {
        self.twin = twin
        self.weatherEngine = weatherEngine
        self.onOpenAutomation = onOpenAutomation
        self.onOpenCamera = onOpenCamera
        self.onOpenDrone = onOpenDrone
        self.onOpenEditor = onOpenEditor
        self.onOpenSettings = onOpenSettings
        self.onFocusModule = onFocusModule
    }

    private var entities: [PropertyEntity] { twin.entities }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Systems").font(.prvioTitle())

                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.md),
                                    GridItem(.flexible(), spacing: Spacing.md)], spacing: Spacing.md) {
                    EnergyTile(summary: PropertyAnalytics.energy(entities))
                    WeatherTile(summary: PropertyAnalytics.weather(entities), engine: weatherEngine)
                    WaterTile(summary: PropertyAnalytics.water(entities))
                    SecurityTile(summary: PropertyAnalytics.security(entities))
                }

                if let engine = weatherEngine, !engine.forecast.isEmpty {
                    WeatherForecastStrip(forecast: engine.forecast)
                }

                Text("Intelligence Tools").font(.prvioHeadline())
                toolRow(icon: "wand.and.stars", title: "Automation Studio",
                        subtitle: "\(twin.automations.count) flows • \(twin.automations.filter(\.isEnabled).count) active",
                        tint: .prvioHorizon, action: onOpenAutomation)
                toolRow(icon: "video.badge.waveform", title: "Camera AI",
                        subtitle: "\(twin.entities.filter { $0.kind == .camera }.count) cameras • live detection",
                        tint: .domainHome, action: onOpenCamera)
                toolRow(icon: "paperplane.fill", title: "Drone & Satellite",
                        subtitle: "Orthomosaic, NDVI & LiDAR onto your twin",
                        tint: .domainForest, action: onOpenDrone)
                toolRow(icon: "pencil.and.outline", title: "Build your Twin",
                        subtitle: "Place trees, ponds, devices on the map",
                        tint: .domainGarden, action: onOpenEditor)
                toolRow(icon: "gearshape.fill", title: "Settings",
                        subtitle: "Units, telemetry interval, notifications",
                        tint: .prvioHorizon, action: onOpenSettings)

                Text("Modules").font(.prvioHeadline())
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                    ForEach(Array(quickModules.enumerated()), id: \.offset) { _, item in
                        Button { onFocusModule(item.module) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: item.icon).font(.title3).foregroundStyle(item.tint)
                                Text(item.label).font(.prvioCaption())
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, Spacing.md)
                            .liquidGlass(.raised, tint: item.tint, interactive: false)
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(Spacing.lg)
            .padding(.top, 60)
        }
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial).ignoresSafeArea()
        }
    }

    private func toolRow(icon: String, title: String, subtitle: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).font(.title2).foregroundStyle(tint).frame(width: 32)
                VStack(alignment: .leading) {
                    Text(title).font(.prvioLabel())
                    Text(subtitle).font(.prvioCaption()).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(Spacing.md)
            .liquidGlass(.raised, tint: tint, interactive: false)
        }.buttonStyle(.plain)
    }

    private var quickModules: [(module: PropertyModule, label: String, icon: String, tint: Color)] {
        [(.forest, "Forest", "tree.fill", .domainForest),
         (.orchard, "Orchard", "apple.logo", .domainOrchard),
         (.pond, "Pond", "drop.fill", .domainPond),
         (.garden, "Garden", "camera.macro", .domainGarden),
         (.greenhouse, "Glass House", "leaf.fill", .domainGreenhouse),
         (.agriculture, "Fields", "field.of.wheat", .domainAgriculture),
         (.home, "Home", "house.fill", .domainHome)]
    }
}

// MARK: - System Tiles

private struct EnergyTile: View {
    var summary: PropertyAnalytics.EnergySummary
    var body: some View {
        SystemTile(title: "Energy", icon: "bolt.fill", tint: .domainEnergy) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(summary.todayKwh)) kWh").font(.prvioMetric())
                Label(summary.isExporting ? "Exporting \(Int(summary.net)) W" : "Drawing \(Int(-summary.net)) W",
                      systemImage: summary.isExporting ? "arrow.up.right" : "arrow.down.right")
                    .font(.prvioCaption())
                    .foregroundStyle(summary.isExporting ? .healthThriving : .healthStressed)
            }
        }
    }
}

private struct WeatherTile: View {
    var summary: PropertyAnalytics.WeatherSummary
    var engine: WeatherEngine?

    private var current: WeatherEngine.Current? { engine?.current }
    private var displayTemp: Double    { current?.tempC       ?? summary.tempC }
    private var displayCond: String    { current?.condition   ?? summary.condition }
    private var displayWind: Double    { current?.windKph     ?? summary.windKph }
    private var displaySymbol: String  { current?.symbolName  ?? summary.symbol }

    var body: some View {
        SystemTile(title: "Weather", icon: displaySymbol, tint: .domainWater) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(displayTemp))°").font(.prvioMetric())
                Text("\(displayCond) · \(Int(displayWind)) kph")
                    .font(.prvioCaption()).foregroundStyle(.secondary)
                if let c = current {
                    Label("UV \(c.uvIndex) · \(Int(c.humidity * 100))% RH",
                          systemImage: c.isDaytime ? "sun.max.fill" : "moon.fill")
                        .font(.prvioCaption()).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct WeatherForecastStrip: View {
    var forecast: [WeatherEngine.DayForecast]
    var body: some View {
        GlassCard(tint: .domainWater) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("7-Day Forecast").font(.prvioCaption()).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(forecast) { day in
                            ForecastDayCell(day: day)
                        }
                    }
                }
            }
        }
    }
}

private struct ForecastDayCell: View {
    var day: WeatherEngine.DayForecast
    var body: some View {
        VStack(spacing: 3) {
            Text(day.date, format: .dateTime.weekday(.abbreviated))
                .font(.system(size: 9)).foregroundStyle(.secondary)
            Image(systemName: day.symbolName)
                .font(.caption).foregroundStyle(.domainWater)
            Text("\(Int(day.highC))°")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Text("\(Int(day.lowC))°")
                .font(.system(size: 9, design: .rounded)).foregroundStyle(.secondary)
            if day.precipProbability > 0.2 {
                Text("\(Int(day.precipProbability * 100))%")
                    .font(.system(size: 8)).foregroundStyle(.domainWater)
            }
        }
        .frame(width: 44)
    }
}

private struct WaterTile: View {
    var summary: PropertyAnalytics.WaterSummary
    var body: some View {
        SystemTile(title: "Water", icon: "drop.fill", tint: .domainWater) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(summary.pondLevelPercent))%").font(.prvioMetric())
                Text("\(summary.pumpsOnline) pumps • \(summary.irrigationValvesOpen) valves open")
                    .font(.prvioCaption()).foregroundStyle(.secondary)
            }
        }
    }
}

private struct SecurityTile: View {
    var summary: PropertyAnalytics.SecuritySummary
    var body: some View {
        SystemTile(title: "Security", icon: summary.allClear ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                   tint: summary.allClear ? .healthThriving : .domainSecurity) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.armed ? "Armed" : "Off").font(.prvioHeadline())
                Text("\(summary.camerasOnline)/\(summary.cameras) cameras online")
                    .font(.prvioCaption()).foregroundStyle(.secondary)
            }
        }
    }
}

private struct SystemTile<Content: View>: View {
    var title: String
    var icon: String
    var tint: Color
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(title, systemImage: icon).font(.prvioLabel()).foregroundStyle(tint)
            content()
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: tint, interactive: false)
    }
}
