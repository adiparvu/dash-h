//
//  GardenView.swift
//  PRVIO EARTH
//
//  Smart Garden dashboard — soil moisture per bed, pH and temperature
//  gauges, watering countdown, companion planting highlights and PRVIO
//  watering recommendations. Reached from the Garden module dashboard.
//

import SwiftUI
import Charts

public struct GardenView: View {
    var twin: DigitalTwinEngine

    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var gardens: [PropertyEntity] {
        twin.entities.filter { $0.kind == .garden }
    }
    private var soilSensors: [PropertyEntity] {
        twin.entities.filter { $0.kind == .soilSensor }
    }
    private var insights: [PrvioInsight] { twin.insights(for: .garden) }

    private var moistureData: [(name: String, moisture: Double)] {
        gardens.compactMap { e in
            guard let m = e.metrics["soilMoisture"] else { return nil }
            return (e.name, m)
        }
    }

    public var body: some View {
        AnalyticsScaffold(title: "Garden", tint: .domainGarden) {
            StatRow(stats: [
                .init(label: "Beds", value: "\(gardens.count)", icon: "camera.macro"),
                .init(label: "Sensors", value: "\(soilSensors.count)", icon: "antenna.radiowaves.left.and.right"),
                .init(label: "Avg Moisture", value: String(format: "%.0f", averageMoisture() * 100), unit: "%", icon: "humidity"),
            ], tint: .domainGarden)

            if !moistureData.isEmpty {
                ChartCard(title: "Soil moisture per bed", tint: .domainGarden) {
                    Chart {
                        ForEach(moistureData, id: \.name) { item in
                            BarMark(x: .value("Bed", item.name), y: .value("Moisture %", item.moisture * 100))
                                .foregroundStyle(moistureColor(item.moisture).gradient)
                                .cornerRadius(6)
                        }
                        RuleMark(y: .value("Target", 50))
                            .foregroundStyle(Color.secondary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .annotation(position: .trailing) {
                                Text("target").font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxisLabel("%")
                    .frame(height: 180)
                }
            }

            ForEach(gardens) { entity in
                if case .garden(let g) = entity.detail {
                    BedCard(entity: entity, profile: g)
                }
            }

            HStack(spacing: Spacing.md) {
                RiskBadge(label: "Low moisture",
                          count: lowMoistureCount(),
                          icon: "exclamationmark.triangle.fill",
                          tint: .healthStressed)
                RiskBadge(label: "Sensors online",
                          count: soilSensors.filter { if case .device(let d) = $0.detail { return d.isOnline }; return false }.count,
                          icon: "checkmark.circle.fill",
                          tint: .domainGarden)
            }

            let nextHours = nextWateringHours()
            InsightFootnote(
                text: insights.first.map { $0.title + ". " + ($0.recommendation ?? "") }
                    ?? "Next watering in \(nextHours > 0 ? "\(nextHours)h" : "now"). PRVIO monitors soil sensors and adjusts schedules automatically.",
                tint: .domainGarden)
        }
    }

    private func averageMoisture() -> Double {
        let vals = gardens.compactMap { $0.metrics["soilMoisture"] }
        return vals.isEmpty ? 0.5 : vals.reduce(0, +) / Double(vals.count)
    }

    private func moistureColor(_ m: Double) -> Color {
        m < 0.35 ? .healthCritical : m < 0.5 ? .healthStressed : .domainGarden
    }

    private func lowMoistureCount() -> Int {
        gardens.filter { ($0.metrics["soilMoisture"] ?? 1) < 0.45 }.count
    }

    private func nextWateringHours() -> Int {
        let profiles = gardens.compactMap { e -> GardenProfile? in
            if case .garden(let g) = e.detail { return g }
            return nil
        }
        let next = profiles.map(\.nextWatering).min() ?? .now.addingTimeInterval(86_400)
        return max(0, Int(next.timeIntervalSinceNow / 3600))
    }
}

// MARK: - Bed card

private struct BedCard: View {
    var entity: PropertyEntity
    var profile: GardenProfile

    var body: some View {
        GlassCard(tint: .domainGarden) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "camera.macro").foregroundStyle(.domainGarden)
                    Text(entity.name).font(.prvioLabel())
                    Spacer()
                    Text(String(format: "%.0f%%", entity.health.score * 100))
                        .font(.prvioCaption()).foregroundStyle(entity.health.score.healthColor)
                }
                Text(profile.beds.joined(separator: " · "))
                    .font(.prvioCaption()).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: Spacing.md) {
                    Label(String(format: "pH %.1f", profile.soilPH), systemImage: "drop.fill")
                    Label(String(format: "%.0f%%", profile.soilMoisture * 100) + " moist.", systemImage: "humidity")
                    Label(profile.mulched ? "Mulched" : "Bare",
                          systemImage: profile.mulched ? "leaf.fill" : "circle.dashed")
                }
                .font(.prvioCaption()).foregroundStyle(.secondary)
                HStack {
                    Label("Water in \(hoursUntil(profile.nextWatering))h", systemImage: "spigot.fill")
                        .font(.prvioCaption()).foregroundStyle(.domainWater)
                    Spacer()
                    if !profile.companions.isEmpty {
                        Text("+ " + profile.companions.prefix(2).joined(separator: ", "))
                            .font(.prvioCaption()).foregroundStyle(.domainGarden)
                    }
                }
            }
        }
    }

    private func hoursUntil(_ date: Date) -> Int {
        max(0, Int(date.timeIntervalSinceNow / 3600))
    }
}
