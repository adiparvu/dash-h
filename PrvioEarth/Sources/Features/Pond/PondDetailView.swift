//
//  PondDetailView.swift
//  PRVIO EARTH
//
//  Rich Smart Pond dashboard: water chemistry gauges, fish inventory,
//  equipment status and PRVIO insights. Reached from the Pond module
//  dashboard's "Water chemistry & life" button.
//

import SwiftUI
import Charts

public struct PondDetailView: View {
    var twin: DigitalTwinEngine

    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var pondEntity: PropertyEntity? {
        twin.entities.first { $0.kind == .pond }
    }
    private var profile: PondProfile? {
        if case .pond(let p)? = pondEntity?.detail { return p }
        return nil
    }
    private var equipment: [PropertyEntity] {
        twin.entities.filter { [.pump, .filter, .aerator].contains($0.kind) }
    }
    private var insights: [PrvioInsight] { twin.insights(for: .pond) }

    public var body: some View {
        AnalyticsScaffold(title: "Pond", tint: .domainPond) {
            if let p = profile, let entity = pondEntity {
                StatRow(stats: [
                    .init(label: "Water Temp", value: String(format: "%.1f", p.waterTempC), unit: "°C", icon: "thermometer.medium"),
                    .init(label: "Fish", value: "\(p.fishCount)", icon: "fish.fill"),
                    .init(label: "Level", value: String(format: "%.0f", p.waterLevelPercent), unit: "%", icon: "drop.fill"),
                ], tint: .domainPond)

                ChartCard(title: "Water Chemistry", tint: .domainPond) {
                    VStack(spacing: Spacing.sm) {
                        ChemGauge(label: "pH", value: p.pH, rangeLow: 6.5, rangeHigh: 8.5, tint: .domainPond)
                        ChemGauge(label: "Oxygen", value: p.dissolvedOxygenMgL, rangeLow: 0, rangeHigh: 12, tint: .domainWater, criticalBelow: 5)
                        ChemGauge(label: "Ammonia", value: p.ammoniaMgL, rangeLow: 0, rangeHigh: 1.0, tint: .domainSecurity, invertScale: true)
                        ChemGauge(label: "Nitrate", value: p.nitrateMgL, rangeLow: 0, rangeHigh: 40, tint: .domainOrchard, invertScale: true)
                    }
                }

                healthHistoryCard(entity: entity)

                if !equipment.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Equipment").font(.prvioHeadline())
                        ForEach(equipment) { device in
                            HStack {
                                Image(systemName: device.kind.symbol).foregroundStyle(.domainPond).frame(width: 24)
                                Text(device.name).font(.prvioLabel())
                                Spacer()
                                if case .device(let d) = device.detail {
                                    Label(d.isOnline ? "Online" : "Offline",
                                          systemImage: d.isOnline ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.prvioCaption())
                                        .foregroundStyle(d.isOnline ? .healthThriving : .healthCritical)
                                }
                            }
                            .padding(Spacing.md)
                            .liquidGlass(.raised, tint: .domainPond, interactive: false)
                        }
                    }
                }

                if p.uvSterilizerOn {
                    InsightFootnote(text: "UV steriliser active — water clarity is optimal. Schedule next filter clean in 8 days.", tint: .domainPond)
                }
            } else {
                Text("No pond data available.").foregroundStyle(.secondary).padding()
            }

            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Alerts").font(.prvioHeadline())
                    ForEach(insights.prefix(3)) { insight in
                        GlassCard(tint: .domainPond) {
                            Label(insight.title, systemImage: insight.severity.symbol).font(.prvioLabel())
                        }
                    }
                }
            }
        }
    }

    private func healthHistoryCard(entity: PropertyEntity) -> some View {
        ChartCard(title: "Health (14 days)", tint: .domainPond) {
            let points: [TimeSeriesPoint] = (0..<14).map { day in
                TimeSeriesPoint(
                    timestamp: .now.addingTimeInterval(Double(day - 14) * 86_400),
                    value: min(1, max(0, entity.health.score + Double.random(in: -0.08...0.06))))
            }
            Chart(points) { pt in
                AreaMark(x: .value("Day", pt.timestamp), y: .value("Health", pt.value))
                    .foregroundStyle(Color.domainPond.gradient.opacity(0.3))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Day", pt.timestamp), y: .value("Health", pt.value))
                    .foregroundStyle(Color.domainPond)
                    .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...1)
            .frame(height: 120)
        }
    }
}

// MARK: - Chemistry Gauge

private struct ChemGauge: View {
    var label: String
    var value: Double
    var rangeLow: Double
    var rangeHigh: Double
    var tint: Color
    var criticalBelow: Double? = nil
    var invertScale: Bool = false

    private var fraction: Double {
        min(1, max(0, (value - rangeLow) / (rangeHigh - rangeLow)))
    }
    private var isAlert: Bool {
        if let cb = criticalBelow { return value < cb }
        if invertScale { return fraction > 0.5 }
        return false
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(label)
                .font(.prvioCaption()).foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1)).frame(height: 8)
                    Capsule()
                        .fill((isAlert ? Color.healthCritical : tint).gradient)
                        .frame(width: geo.size.width * fraction, height: 8)
                }
            }
            .frame(height: 8)
            Text(String(format: "%.2f", value))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isAlert ? .healthCritical : .primary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}
