//
//  GreenhouseView.swift
//  PRVIO EARTH
//
//  Smart Greenhouse (Glass House) dashboard — climate gauges (temp,
//  humidity, CO₂, light), grow-light and ventilation status, active crop
//  roster and next-harvest countdown. Reached from the Greenhouse module.
//

import SwiftUI
import Charts

public struct GreenhouseView: View {
    var twin: DigitalTwinEngine

    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var greenhouses: [PropertyEntity] {
        twin.entities.filter { $0.kind == .greenhouse }
    }
    private var growLights: [PropertyEntity] {
        twin.entities.filter { $0.kind == .growLight }
    }
    private var insights: [PrvioInsight] { twin.insights(for: .greenhouse) }

    private var profiles: [GreenhouseProfile] {
        greenhouses.compactMap { e in
            if case .greenhouse(let g) = e.detail { return g }
            return nil
        }
    }

    public var body: some View {
        AnalyticsScaffold(title: "Glass House", tint: .domainGreenhouse) {
            StatRow(stats: [
                .init(label: "Zones", value: "\(profiles.map(\.zones).reduce(0, +))", icon: "square.grid.2x2.fill"),
                .init(label: "Crop types", value: "\(allCrops().count)", icon: "leaf.fill"),
                .init(label: "Grow lights", value: "\(growLights.count)", icon: "lightbulb.fill"),
            ], tint: .domainGreenhouse)

            if let p = profiles.first {
                ChartCard(title: "Climate", tint: .domainGreenhouse) {
                    VStack(spacing: Spacing.md) {
                        ClimateRow(icon: "thermometer.medium", label: "Temperature",
                                   value: String(format: "%.1f°C", p.temperatureC),
                                   tint: .domainGreenhouse,
                                   isAlert: p.temperatureC > 35 || p.temperatureC < 12)
                        ClimateRow(icon: "humidity", label: "Humidity",
                                   value: String(format: "%.0f%%", p.humidity * 100),
                                   tint: .domainWater,
                                   isAlert: p.humidity < 0.4 || p.humidity > 0.9)
                        ClimateRow(icon: "wind", label: "CO₂",
                                   value: String(format: "%.0f ppm", p.co2Ppm),
                                   tint: .domainGreenhouse,
                                   isAlert: p.co2Ppm > 1500)
                        ClimateRow(icon: "lightbulb.fill", label: "Light intensity",
                                   value: String(format: "%.0f lux", p.lightLux),
                                   tint: .domainEnergy,
                                   isAlert: p.lightLux < 3000)
                    }
                }
            }

            let crops = allCrops()
            if !crops.isEmpty {
                ChartCard(title: "Active crops", tint: .domainGreenhouse) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(crops, id: \.self) { crop in
                                Text(crop)
                                    .font(.prvioCaption())
                                    .padding(.horizontal, Spacing.sm + 2)
                                    .padding(.vertical, 4)
                                    .liquidGlass(.raised, tint: .domainGreenhouse, interactive: false)
                            }
                        }
                    }
                }
            }

            HStack(spacing: Spacing.md) {
                RiskBadge(label: "Grow lights on", count: profiles.filter(\.growLightsOn).count, icon: "lightbulb.fill", tint: .domainEnergy)
                RiskBadge(label: "Vents open", count: profiles.filter(\.ventilationOn).count, icon: "wind", tint: .domainGreenhouse)
            }

            if let harvest = profiles.compactMap(\.nextHarvest).min() {
                InsightFootnote(
                    text: "Next harvest window opens \(harvest.formatted(.dateTime.month().day())). PRVIO will send a pick-time notification 24 h before optimal maturity.",
                    tint: .domainGreenhouse)
            }

            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Alerts").font(.prvioHeadline())
                    ForEach(insights.prefix(2)) { insight in
                        GlassCard(tint: .domainGreenhouse) {
                            Label(insight.title, systemImage: insight.severity.symbol).font(.prvioLabel())
                        }
                    }
                }
            }
        }
    }

    private func allCrops() -> [String] {
        var seen = Set<String>()
        return profiles.flatMap(\.crops).filter { seen.insert($0).inserted }
    }
}

// MARK: - Climate row

private struct ClimateRow: View {
    var icon: String
    var label: String
    var value: String
    var tint: Color
    var isAlert: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(isAlert ? Color.healthCritical : tint)
                .frame(width: 24)
            Text(label).font(.prvioLabel()).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.prvioLabel())
                .foregroundStyle(isAlert ? Color.healthCritical : Color.primary)
            if isAlert {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.healthCritical)
                    .font(.caption)
            }
        }
    }
}
