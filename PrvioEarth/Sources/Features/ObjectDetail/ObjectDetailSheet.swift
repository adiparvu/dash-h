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

    @State private var showInspect = false
    @State private var showAutomation = false
    @State private var showForecast = false

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
        .sheet(isPresented: $showInspect) {
            InspectPanel(entity: entity, twin: twin)
                .presentationDetents([.medium, .large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAutomation) {
            AutomationProposalView(entity: entity, twin: twin)
                .presentationDetents([.medium])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
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
        case .agriculture(let a):
            return [
                MetricTile(label: "Crop", value: a.cropType, icon: "field.of.wheat", tint: .domainAgriculture),
                MetricTile(label: "Area", value: String(format: "%.1f", a.fieldAreaHa), unit: "ha", icon: "rectangle.inset.filled", tint: .domainAgriculture),
                MetricTile(label: "Stage", value: a.growthStage.rawValue.capitalized, icon: a.growthStage.icon, tint: .domainAgriculture),
                MetricTile(label: "Yield Forecast", value: String(format: "%.1f", a.yieldForecastTha), unit: "t/ha", icon: "chart.line.uptrend.xyaxis", tint: .healthThriving),
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

    // MARK: - History / Forecast

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Label(showForecast ? "7-Day Forecast" : "Health History",
                      systemImage: showForecast ? "chart.line.uptrend.xyaxis" : "chart.xyaxis.line")
                    .font(.prvioHeadline())
                Spacer()
                Picker("", selection: $showForecast) {
                    Text("History").tag(false)
                    Text("Forecast").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            GlassCard {
                let points = showForecast ? twin.forecastHealth(for: entity.id) : historyPoints
                Chart(points) { point in
                    AreaMark(x: .value("Time", point.timestamp), y: .value("Health", point.value))
                        .foregroundStyle(tint.gradient.opacity(showForecast ? 0.2 : 0.4))
                    LineMark(x: .value("Time", point.timestamp), y: .value("Health", point.value))
                        .foregroundStyle(showForecast ? tint.opacity(0.8) : tint)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: showForecast ? [5, 3] : []))
                        .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...1)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel(
                            format: showForecast ? .dateTime.day().month() : .dateTime.hour().minute())
                            .font(.system(size: 9)).foregroundStyle(Color.secondary)
                        AxisGridLine(stroke: StrokeStyle(dash: [2, 4]))
                            .foregroundStyle(Color.secondary.opacity(0.25))
                    }
                }
                .frame(height: 130)
                if showForecast {
                    Text("AI-projected · mean-reversion model")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 2)
                }
            }
        }
    }

    /// Uses real rolling telemetry once ≥5 samples have been recorded; falls back to
    /// UUID-seeded placeholder so the chart is never empty on first open.
    private var historyPoints: [TimeSeriesPoint] {
        let real = twin.healthHistory(for: entity.id)
        return real.count >= 5 ? real : sampleHistory()
    }

    /// 14-day health history seeded from the entity's UUID so the sparkline is
    /// stable across renders — no random jumps each time the sheet opens.
    private func sampleHistory() -> [TimeSeriesPoint] {
        let seed = Double(abs(entity.id.hashValue) % 10_000) / 10_000.0
        return (0..<14).map { day in
            let t = Double(day) / 13.0
            let wave = sin(t * .pi * 2.5 + seed * .pi * 2) * 0.08
            let trend = (seed > 0.5 ? -0.01 : 0.01) * Double(14 - day)
            let v = min(1, max(0, entity.health.score + wave + trend * 0.3))
            return TimeSeriesPoint(
                timestamp: .now.addingTimeInterval(Double(day - 14) * 86_400),
                value: v)
        }
    }

    // MARK: - Maintenance & Automation

    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Actions", systemImage: "wrench.and.screwdriver.fill").font(.prvioHeadline())
            HStack(spacing: Spacing.sm) {
                GlassButton("Inspect", systemImage: "camera.viewfinder", tint: tint) { showInspect = true }
                GlassButton("Automate", systemImage: "bolt.badge.automatic", tint: tint) { showAutomation = true }
                ShareLink(item: entityTelemetryText,
                          subject: Text("Entity Report"),
                          message: Text("Exported from PRVIO Earth")) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "note.text")
                        Text("Log")
                    }
                    .font(.prvioLabel())
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm + 2)
                    .liquidGlass(.floating, tint: tint, interactive: false)
                }
            }
        }
    }

    private var entityTelemetryText: String {
        var lines = [
            "PRVIO Earth — Entity Log",
            "Entity: \(entity.name)",
            "Module: \(entity.kind.module.title)",
            "Health: \(Int(entity.health.score * 100))%",
            "Status: \(entity.health.status.rawValue.capitalized)",
            "Date: \(Date.now.formatted(date: .long, time: .shortened))",
        ]
        for (key, value) in entity.metrics.sorted(by: { $0.key < $1.key }) {
            lines.append("\(key): \(String(format: "%.2f", value))")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Inspect Panel

private struct DiagnosticItem {
    var title: String
    var value: String
    var status: DiagStatus
    enum DiagStatus { case ok, warning, critical }
}

private struct DiagnosticRow: View {
    var item: DiagnosticItem

    private var statusColor: Color {
        switch item.status {
        case .ok: return .healthThriving
        case .warning: return .healthStressed
        case .critical: return .healthCritical
        }
    }
    private var statusSymbol: String {
        switch item.status {
        case .ok: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: statusSymbol).foregroundStyle(statusColor)
            Text(item.title).font(.prvioLabel())
            Spacer()
            Text(item.value).font(.prvioCaption()).foregroundStyle(.secondary)
        }
    }
}

private struct InspectPanel: View {
    var entity: PropertyEntity
    var twin: DigitalTwinEngine
    @Environment(\.dismiss) private var dismiss

    private var tint: Color { entity.kind.module.tint }
    private var related: [PrvioInsight] {
        twin.insights.filter { $0.relatedEntityIDs.contains(entity.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                panelHeader
                GlassCard(tint: tint) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Label("Current Status", systemImage: entity.kind.symbol)
                            .font(.prvioHeadline())
                        Text(inspectSummary).font(.prvioLabel()).foregroundStyle(.secondary)
                    }
                }
                if !diagnosticItems.isEmpty {
                    GlassCard(tint: tint) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Label("Diagnostics", systemImage: "stethoscope").font(.prvioHeadline())
                            ForEach(diagnosticItems, id: \.title) { DiagnosticRow(item: $0) }
                        }
                    }
                }
                if !related.isEmpty {
                    GlassCard(tint: tint) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Label("AI Observations", systemImage: "sparkles")
                                .font(.prvioHeadline()).foregroundStyle(tint)
                            ForEach(related) { insight in
                                Text("• \(insight.title)").font(.prvioCaption()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial).ignoresSafeArea()
        }
    }

    private var panelHeader: some View {
        HStack {
            Text("Inspection Report").font(.prvioTitle())
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
            }.buttonStyle(.plain)
        }
    }

    private var inspectSummary: String {
        switch entity.detail {
        case .tree(let t):
            return "\(entity.name) is a \(t.species) standing \(String(format: "%.1f", t.heightMeters)) m tall, \(t.ageYears) yr old. Health: \(Int(entity.health.score * 100))%."
        case .orchard(let o):
            return "\(entity.name) (\(o.species)) in \(o.phenophase.rawValue) phase. Expected yield \(String(format: "%.0f", o.expectedYieldKg)) kg. Irrigation \(o.irrigationActive ? "active" : "off")."
        case .pond(let p):
            return "\(entity.name) at \(String(format: "%.1f", p.waterTempC))°C, pH \(String(format: "%.1f", p.pH)), O₂ \(String(format: "%.1f", p.dissolvedOxygenMgL)) mg/L. \(p.fishCount) fish."
        case .device(let d):
            return "\(entity.name) (\(d.protocolType.rawValue)) is \(d.isOnline ? "online" : "offline"). Firmware \(d.firmware)."
        case .garden(let g):
            return "\(entity.name) soil moisture \(Int(g.soilMoisture * 100))%, pH \(String(format: "%.1f", g.soilPH)), \(String(format: "%.0f", g.soilTemperatureC))°C."
        case .greenhouse(let g):
            return "\(entity.name) at \(String(format: "%.1f", g.temperatureC))°C, \(Int(g.humidity * 100))% humidity, CO₂ \(String(format: "%.0f", g.co2Ppm)) ppm."
        case .agriculture(let a):
            return "\(entity.name) (\(a.cropType)) in \(a.growthStage.rawValue) over \(String(format: "%.1f", a.fieldAreaHa)) ha. Forecast \(String(format: "%.1f", a.yieldForecastTha)) t/ha."
        case .none:
            return "\(entity.name) health: \(Int(entity.health.score * 100))%."
        }
    }

    private var diagnosticItems: [DiagnosticItem] {
        switch entity.detail {
        case .pond(let p):
            return [
                DiagnosticItem(title: "Dissolved Oxygen",
                    value: "\(String(format: "%.1f", p.dissolvedOxygenMgL)) mg/L",
                    status: p.dissolvedOxygenMgL < 4 ? .critical : p.dissolvedOxygenMgL < 6 ? .warning : .ok),
                DiagnosticItem(title: "pH Level",
                    value: String(format: "%.1f", p.pH),
                    status: (p.pH < 6 || p.pH > 9) ? .critical : (p.pH < 6.5 || p.pH > 8.5) ? .warning : .ok),
            ]
        case .tree(let t):
            return [
                DiagnosticItem(title: "Carbon Storage",
                    value: "\(String(format: "%.0f", t.carbonStorageKg)) kg", status: .ok),
                DiagnosticItem(title: "Soil pH",
                    value: String(format: "%.1f", t.soilPH),
                    status: (t.soilPH < 5.5 || t.soilPH > 7.5) ? .warning : .ok),
            ]
        case .greenhouse(let g):
            return [
                DiagnosticItem(title: "CO₂ Level",
                    value: "\(String(format: "%.0f", g.co2Ppm)) ppm",
                    status: g.co2Ppm > 1500 ? .critical : g.co2Ppm > 1200 ? .warning : .ok),
                DiagnosticItem(title: "Humidity",
                    value: "\(Int(g.humidity * 100))%",
                    status: (g.humidity < 0.4 || g.humidity > 0.9) ? .warning : .ok),
            ]
        default:
            return []
        }
    }
}

// MARK: - Automation Proposal

private struct AutomationProposalView: View {
    var entity: PropertyEntity
    var twin: DigitalTwinEngine
    @Environment(\.dismiss) private var dismiss
    @State private var didCreate = false

    private var tint: Color { entity.kind.module.tint }

    private var proposedAutomation: Automation {
        switch entity.detail {
        case .orchard:
            return Automation(name: "Irrigation Trigger — \(entity.name)", nodes: [
                .init(role: .trigger, title: "Soil moisture < 40%", config: "threshold:0.4"),
                .init(role: .condition, title: "No rain forecast 24 h", config: "weather:noRain"),
                .init(role: .action, title: "Start drip irrigation 30 min", config: "duration:1800"),
            ], module: entity.kind.module)
        case .pond:
            return Automation(name: "Aerator Trigger — \(entity.name)", nodes: [
                .init(role: .trigger, title: "Dissolved O₂ < 5 mg/L", config: "threshold:5.0"),
                .init(role: .condition, title: "Aerator not running", config: "device:aerator"),
                .init(role: .action, title: "Activate pond aerator 1 h", config: "duration:3600"),
            ], module: .pond)
        case .greenhouse:
            return Automation(name: "Vent Control — \(entity.name)", nodes: [
                .init(role: .trigger, title: "Temperature > 28°C", config: "threshold:28"),
                .init(role: .condition, title: "Grow lights active", config: "device:lights"),
                .init(role: .action, title: "Open roof vents", config: "device:vents"),
            ], module: .greenhouse)
        case .device:
            return Automation(name: "Device Alert — \(entity.name)", nodes: [
                .init(role: .trigger, title: "Device goes offline", config: "status:offline"),
                .init(role: .condition, title: "No alert sent in 1 h", config: "cooldown:3600"),
                .init(role: .action, title: "Send push notification", config: "alert:push"),
            ], module: .home)
        case .garden:
            return Automation(name: "Watering — \(entity.name)", nodes: [
                .init(role: .trigger, title: "Soil moisture < 35%", config: "threshold:0.35"),
                .init(role: .condition, title: "Between 6 am and 9 am", config: "time:06:00-09:00"),
                .init(role: .action, title: "Run garden irrigation 15 min", config: "duration:900"),
            ], module: .garden)
        case .agriculture:
            return Automation(name: "Field Monitor — \(entity.name)", nodes: [
                .init(role: .trigger, title: "Yield forecast drops > 10%", config: "threshold:0.1"),
                .init(role: .condition, title: "Crop in active growth", config: "stage:growth"),
                .init(role: .action, title: "Flag for agronomist review", config: "alert:agronomist"),
            ], module: .agriculture)
        default:
            return Automation(name: "Health Watch — \(entity.name)", nodes: [
                .init(role: .trigger, title: "Health score < 40%", config: "threshold:0.4"),
                .init(role: .condition, title: "Alert not sent in 24 h", config: "cooldown:86400"),
                .init(role: .action, title: "Send maintenance alert", config: "alert:push"),
            ], module: entity.kind.module)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            proposalHeader
            Text("PRVIO Intelligence suggests this automation for \(entity.name):")
                .font(.prvioLabel()).foregroundStyle(.secondary)
            nodeFlow
            if didCreate {
                Label("Automation created!", systemImage: "checkmark.circle.fill")
                    .font(.prvioLabel()).foregroundStyle(.healthThriving)
                    .transition(.scale.combined(with: .opacity))
            }
            footerButtons
        }
        .padding(Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial).ignoresSafeArea()
        }
    }

    private var proposalHeader: some View {
        HStack {
            Label("Automation Proposal", systemImage: "bolt.badge.automatic").font(.prvioTitle())
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
            }.buttonStyle(.plain)
        }
    }

    private var nodeFlow: some View {
        VStack(spacing: 2) {
            ForEach(Array(proposedAutomation.nodes.enumerated()), id: \.offset) { idx, node in
                NodeRowAndArrow(node: node, isLast: idx == proposedAutomation.nodes.count - 1)
            }
        }
    }

    private var footerButtons: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Cancel").font(.prvioLabel())
                    .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm + 2)
                    .liquidGlass(.floating, tint: .prvioMist, interactive: false)
            }.buttonStyle(.plain)
            Spacer()
            Button {
                let a = proposedAutomation
                twin.addAutomation(a)
                withAnimation(.prvioMorph) { didCreate = true }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    dismiss()
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Automation")
                }
                .font(.prvioLabel())
                .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm + 2)
                .liquidGlass(.floating, tint: .prvioHorizon, interactive: false)
            }.buttonStyle(.plain).disabled(didCreate)
        }
    }
}

private struct NodeRowAndArrow: View {
    var node: Automation.Node
    var isLast: Bool

    var body: some View {
        VStack(spacing: 2) {
            AutomationNodeRow(node: node)
            if !isLast {
                Image(systemName: "arrow.down").foregroundStyle(.secondary).font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

private struct AutomationNodeRow: View {
    var node: Automation.Node

    private var color: Color {
        switch node.role {
        case .trigger: return .domainEnergy
        case .condition: return .prvioHorizon
        case .action: return .healthThriving
        }
    }
    private var symbol: String {
        switch node.role {
        case .trigger: return "bolt.fill"
        case .condition: return "checklist"
        case .action: return "play.fill"
        }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 20)
            Text(node.role.rawValue.capitalized).font(.prvioCaption()).foregroundStyle(color)
                .frame(width: 64, alignment: .leading)
            Text(node.title).font(.prvioLabel()).lineLimit(1)
        }
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: color, interactive: false)
    }
}
