//
//  AgricultureView.swift
//  PRVIO EARTH
//
//  Smart Agriculture dashboard — field health overview, NPK analysis,
//  growth-stage distribution, irrigation efficiency and yield forecast
//  per crop zone. Reached from the Fields module dashboard.
//

import SwiftUI
import Charts

public struct AgricultureView: View {
    var twin: DigitalTwinEngine

    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var fields: [PropertyEntity] {
        twin.entities.filter { $0.kind == .cropZone }
    }
    private var pivots: [PropertyEntity] {
        twin.entities.filter { $0.kind == .irrigationPivot }
    }
    private var insights: [PrvioInsight] { twin.insights(for: .agriculture) }

    private var profiles: [AgricultureProfile] {
        fields.compactMap { e in
            if case .agriculture(let a) = e.detail { return a }
            return nil
        }
    }

    private var npkData: [(label: String, n: Double, p: Double, k: Double)] {
        fields.compactMap { e in
            if case .agriculture(let a) = e.detail {
                return (e.name, a.npk.nitrogen, a.npk.phosphorus, a.npk.potassium)
            }
            return nil
        }
    }

    public var body: some View {
        AnalyticsScaffold(title: "Fields", tint: .domainAgriculture) {
            StatRow(stats: [
                .init(label: "Fields", value: "\(fields.count)", icon: "field.of.wheat"),
                .init(label: "Total Area", value: String(format: "%.1f", totalArea()), unit: "ha", icon: "rectangle.inset.filled"),
                .init(label: "Avg Yield", value: String(format: "%.1f", avgYield()), unit: "t/ha", icon: "chart.line.uptrend.xyaxis"),
            ], tint: .domainAgriculture)

            if !npkData.isEmpty {
                ChartCard(title: "NPK profile per field", tint: .domainAgriculture) {
                    Chart {
                        ForEach(npkData, id: \.label) { row in
                            BarMark(x: .value("Field", row.label), y: .value("N (kg/ha)", row.n))
                                .foregroundStyle(Color.healthThriving.gradient)
                                .cornerRadius(4)
                            BarMark(x: .value("Field", row.label), y: .value("P (kg/ha)", row.p))
                                .foregroundStyle(Color.domainWater.gradient)
                                .cornerRadius(4)
                            BarMark(x: .value("Field", row.label), y: .value("K (kg/ha)", row.k))
                                .foregroundStyle(Color.domainOrchard.gradient)
                                .cornerRadius(4)
                        }
                    }
                    .chartForegroundStyleScale([
                        "N (kg/ha)": Color.healthThriving,
                        "P (kg/ha)": Color.domainWater,
                        "K (kg/ha)": Color.domainOrchard,
                    ])
                    .chartYAxisLabel("kg/ha")
                    .frame(height: 180)
                }
            }

            if !profiles.isEmpty {
                ChartCard(title: "Growth stages", tint: .domainAgriculture) {
                    let stageCounts = Dictionary(grouping: profiles, by: \.growthStage)
                        .map { (stage: $0.key, count: $0.value.count) }
                        .sorted { $0.stage.rawValue < $1.stage.rawValue }
                    Chart(stageCounts, id: \.stage) { item in
                        SectorMark(angle: .value("Fields", item.count), innerRadius: .ratio(0.55))
                            .foregroundStyle(by: .value("Stage", item.stage.rawValue.capitalized))
                    }
                    .chartLegend(.visible)
                    .frame(height: 180)
                }
            }

            ForEach(fields) { entity in
                if case .agriculture(let a) = entity.detail {
                    FieldCard(entity: entity, profile: a)
                }
            }

            HStack(spacing: Spacing.md) {
                RiskBadge(label: "Pivots online",
                          count: pivots.filter { if case .device(let d) = $0.detail { return d.isOnline }; return false }.count,
                          icon: "arrow.clockwise.circle.fill",
                          tint: .domainAgriculture)
                RiskBadge(label: "Low moisture",
                          count: profiles.filter { $0.soilMoisture < 0.35 }.count,
                          icon: "exclamationmark.triangle.fill",
                          tint: .healthStressed)
            }

            if !insights.isEmpty {
                InsightFootnote(text: insights.first.map { $0.title + ". " + ($0.recommendation ?? "") }
                    ?? "PRVIO monitors soil, weather and market data to optimise field schedules automatically.",
                    tint: .domainAgriculture)
            }
        }
    }

    private func totalArea() -> Double {
        profiles.reduce(0) { $0 + $1.fieldAreaHa }
    }

    private func avgYield() -> Double {
        let vals = profiles.map(\.yieldForecastTha)
        return vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
    }
}

// MARK: - Field Card

private struct FieldCard: View {
    var entity: PropertyEntity
    var profile: AgricultureProfile

    var body: some View {
        GlassCard(tint: .domainAgriculture) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "field.of.wheat").foregroundStyle(.domainAgriculture)
                    Text(entity.name).font(.prvioLabel())
                    Spacer()
                    Text(String(format: "%.1f ha", profile.fieldAreaHa))
                        .font(.prvioCaption()).foregroundStyle(.secondary)
                }
                Text(profile.cropType + " · " + profile.soilType)
                    .font(.prvioCaption()).foregroundStyle(.secondary)
                HStack(spacing: Spacing.sm) {
                    Label(profile.growthStage.rawValue.capitalized,
                          systemImage: profile.growthStage.icon)
                        .font(.prvioCaption()).foregroundStyle(.domainAgriculture)
                    Spacer()
                    Label(String(format: "%.0f%% moist.", profile.soilMoisture * 100),
                          systemImage: "humidity")
                        .font(.prvioCaption())
                        .foregroundStyle(profile.soilMoisture < 0.35 ? Color.healthCritical : Color.domainWater)
                }
                HStack(spacing: Spacing.md) {
                    npkPill("N", value: profile.npk.nitrogen, color: .healthThriving)
                    npkPill("P", value: profile.npk.phosphorus, color: .domainWater)
                    npkPill("K", value: profile.npk.potassium, color: .domainOrchard)
                    Spacer()
                    Label(String(format: "%.1f t/ha", profile.yieldForecastTha), systemImage: "chart.line.uptrend.xyaxis")
                        .font(.prvioCaption()).foregroundStyle(.healthThriving)
                }
                Label("Harvest: " + profile.expectedHarvest.formatted(.dateTime.month().day()),
                      systemImage: "calendar")
                    .font(.prvioCaption()).foregroundStyle(.secondary)
            }
        }
    }

    private func npkPill(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.prvioCaption()).foregroundStyle(color)
            Text(String(format: "%.0f", value)).font(.system(.caption2, design: .monospaced))
        }
    }
}
