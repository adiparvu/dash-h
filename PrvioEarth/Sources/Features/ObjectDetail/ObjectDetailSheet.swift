//
//  ObjectDetailSheet.swift
//  PRVIO EARTH
//
//  The Liquid Glass detail sheet that morphs up when any entity on the
//  twin is tapped. Adapts its content to the entity kind — live metrics,
//  history, AI insights, maintenance and automation controls — without
//  ever feeling like a generic form. One sheet, every object.
//

import SwiftUI
import Charts

public struct ObjectDetailSheet: View {
    var entity: PropertyEntity
    var twin: DigitalTwinEngine

    private var tint: Color { entity.kind.module.tint }
    private var relatedInsights: [PrvioInsight] {
        twin.insights.filter { $0.relatedEntityIDs.contains(entity.id) }
    }

    public init(entity: PropertyEntity, twin: DigitalTwinEngine) {
        self.entity = entity; self.twin = twin
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                metricsSection
                if !relatedInsights.isEmpty { insightsSection }
                historySection
                maintenanceSection
            }
            .padding(Spacing.lg)
        }
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(tint.opacity(0.12)))
                .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(tint.opacity(0.2)).frame(width: 64, height: 64)
                Image(systemName: entity.kind.symbol)
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(entity.name).font(.prvioTitle()).lineLimit(1)
                Text(entity.health.status.rawValue.capitalized)
                    .font(.prvioLabel()).foregroundStyle(entity.health.score.healthColor)
            }
            Spacer()
            HealthRing(score: entity.health.score, lineWidth: 8)
                .frame(width: 56, height: 56)
        }
    }

    // MARK: - Live Metrics (kind-adaptive)

    private var metricsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
            ForEach(metricTiles, id: \.label) { tile in tile }
        }
    }

    private var metricTiles: [MetricTile] {
        switch entity.detail {
        case .pond(let p):
            return [
                MetricTile(label: "Water Temp", value: String(format: "%.1f", p.waterTempC), unit: "°C", icon: "thermometer.medium", tint: .domainPond),
                MetricTile(label: "pH", value: String(format: "%.1f", p.pH), icon: "drop.degreesign", tint: .domainPond),
                MetricTile(label: "Oxygen", value: String(format: "%.1f", p.dissolvedOxygenMgL), unit: "mg/L", icon: "wind", tint: .domainWater, trend: p.dissolvedOxygenMgL < 5 ? .down : .flat),
                MetricTile(label: "Fish", value: "\(p.fishCount)", icon: "fish.fill", tint: .domainPond),
            ]
        case .tree(let t):
            return [
                MetricTile(label: "Height", value: String(format: "%.1f", t.heightMeters), unit: "m", icon: "arrow.up.to.line", tint: .domainForest),
                MetricTile(label: "Age", value: "\(t.ageYears)", unit: "yr", icon: "calendar", tint: .domainForest),
                MetricTile(label: "Carbon", value: String(format: "%.0f", t.carbonStorageKg), unit: "kg", icon: "leaf.fill", tint: .domainForest, trend: .up),
                MetricTile(label: "Soil pH", value: String(format: "%.1f", t.soilPH), icon: "humidity", tint: .domainGarden),
            ]
        case .orchard(let o):
            return [
                MetricTile(label: "Expected Yield", value: String(format: "%.0f", o.expectedYieldKg), unit: "kg", icon: "scalemass.fill", tint: .domainOrchard, trend: .up),
                MetricTile(label: "Phase", value: o.phenophase.rawValue.capitalized, icon: "leaf.arrow.circlepath", tint: .domainOrchard),
                MetricTile(label: "Irrigation", value: o.irrigationActive ? "On" : "Off", icon: "spigot.fill", tint: .domainWater),
                MetricTile(label: "Last Harvest", value: String(format: "%.0f", o.lastHarvestKg), unit: "kg", icon: "basket.fill", tint: .domainOrchard),
            ]
        case .device(let d):
            return [
                MetricTile(label: "Status", value: d.isOnline ? "Online" : "Offline", icon: "dot.radiowaves.left.and.right", tint: d.isOnline ? .healthThriving : .healthCritical),
                MetricTile(label: "Protocol", value: d.protocolType.rawValue.capitalized, icon: "antenna.radiowaves.left.and.right", tint: .domainHome),
                MetricTile(label: "Power", value: d.powerWatts.map { String(format: "%.0f", $0) } ?? "—", unit: "W", icon: "bolt.fill", tint: .domainEnergy),
                MetricTile(label: "Firmware", value: d.firmware, icon: "cpu", tint: .domainHome),
            ]
        case .garden(let g):
            return [
                MetricTile(label: "Soil Moisture", value: String(format: "%.0f", g.soilMoisture * 100), unit: "%", icon: "humidity", tint: .domainGarden, trend: g.soilMoisture < 0.4 ? .down : .flat),
                MetricTile(label: "Soil pH", value: String(format: "%.1f", g.soilPH), icon: "drop.fill", tint: .domainGarden),
                MetricTile(label: "Soil Temp", value: String(format: "%.0f", g.soilTemperatureC), unit: "°C", icon: "thermometer.medium", tint: .domainGarden),
                MetricTile(label: "Sun Hours", value: String(format: "%.1f", g.sunHoursPerDay), unit: "h", icon: "sun.max.fill", tint: .domainOrchard),
            ]
        case .greenhouse(let g):
            return [
                MetricTile(label: "Temperature", value: String(format: "%.1f", g.temperatureC), unit: "°C", icon: "thermometer.medium", tint: .domainGreenhouse),
                MetricTile(label: "Humidity", value: String(format: "%.0f", g.humidity * 100), unit: "%", icon: "humidity", tint: .domainWater),
                MetricTile(label: "CO₂", value: String(format: "%.0f", g.co2Ppm), unit: "ppm", icon: "wind", tint: g.co2Ppm > 1200 ? .healthStressed : .domainGreenhouse),
                MetricTile(label: "Grow Lights", value: g.growLightsOn ? "On" : "Off", icon: "lightbulb.fill", tint: .domainEnergy),
            ]
        case .none:
            return entity.metrics.sorted(by: { $0.key < $1.key }).prefix(4).map {
                MetricTile(label: $0.key, value: String(format: "%.1f", $0.value), icon: "gauge.medium", tint: tint)
            }
        }
    }

    // MARK: - AI Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("PRVIO Insights", systemImage: "sparkles").font(.prvioHeadline()).foregroundStyle(tint)
            ForEach(relatedInsights) { insight in
                GlassCard(tint: tint) {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: insight.severity.symbol)
                            .foregroundStyle(insight.severity == .critical ? .healthCritical : .healthStressed)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title).font(.prvioLabel())
                            Text(insight.detail).font(.prvioCaption()).foregroundStyle(.secondary)
                            if let rec = insight.recommendation {
                                Text(rec).font(.prvioCaption()).foregroundStyle(tint).padding(.top, 2)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("History", systemImage: "chart.xyaxis.line").font(.prvioHeadline())
            GlassCard {
                Chart(sampleHistory()) { point in
                    AreaMark(x: .value("Time", point.timestamp), y: .value("Health", point.value))
                        .foregroundStyle(tint.gradient.opacity(0.4))
                    LineMark(x: .value("Time", point.timestamp), y: .value("Health", point.value))
                        .foregroundStyle(tint)
                        .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...1)
                .frame(height: 120)
            }
        }
    }

    private func sampleHistory() -> [TimeSeriesPoint] {
        (0..<14).map { day in
            TimeSeriesPoint(
                timestamp: .now.addingTimeInterval(Double(day - 14) * 86_400),
                value: min(1, max(0, entity.health.score + Double.random(in: -0.12...0.08))))
        }
    }

    // MARK: - Maintenance & Automation

    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Actions", systemImage: "wrench.and.screwdriver.fill").font(.prvioHeadline())
            HStack {
                GlassButton("Inspect", systemImage: "camera.viewfinder", tint: tint) {}
                GlassButton("Automate", systemImage: "bolt.badge.automatic", tint: tint) {}
                GlassButton("Log", systemImage: "note.text", tint: tint) {}
            }
        }
    }
}
