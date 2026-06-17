//
//  HomeView.swift
//  PRVIO EARTH
//
//  Smart Home dashboard — device grid, energy flow (solar generation vs
//  consumption), security overview, and PRVIO home recommendations.
//  Reached from the Home module dashboard.
//

import SwiftUI
import Charts

public struct HomeView: View {
    var twin: DigitalTwinEngine

    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var devices: [PropertyEntity] {
        twin.entities.filter { [.camera, .gate, .solarPanel, .irrigationValve,
                                .pump, .sensor, .equipment].contains($0.kind) }
    }
    private var cameras: [PropertyEntity] { twin.entities.filter { $0.kind == .camera } }
    private var solarPanels: [PropertyEntity] { twin.entities.filter { $0.kind == .solarPanel } }
    private var insights: [PrvioInsight] { twin.insights(for: .home) }

    private var totalSolarW: Double {
        solarPanels.compactMap { $0.metrics["powerW"] }.reduce(0, +)
    }
    private var totalLoadW: Double {
        devices.compactMap { d -> Double? in
            guard case .device(let dev) = d.detail, dev.isOn else { return nil }
            return dev.powerWatts
        }.reduce(0, +)
    }
    private var isExporting: Bool { totalSolarW > totalLoadW }

    private var energyHistory: [EnergyPoint] {
        (0..<24).map { hour in
            let gen = max(0, totalSolarW * sin(Double(hour - 6) * .pi / 12))
            let load = totalLoadW * Double.random(in: 0.6...1.1)
            return EnergyPoint(hour: hour, generation: gen, load: load)
        }
    }

    public var body: some View {
        AnalyticsScaffold(title: "Home", tint: .domainHome) {
            StatRow(stats: [
                .init(label: "Devices", value: "\(devices.count)", icon: "house.fill"),
                .init(label: "Solar", value: String(format: "%.1f", totalSolarW / 1000), unit: "kW", icon: "sun.max.fill"),
                .init(label: "Cameras", value: "\(cameras.count)", icon: "video.fill"),
            ], tint: .domainHome)

            ChartCard(title: "Energy today", tint: .domainHome) {
                Chart(energyHistory, id: \.hour) { point in
                    AreaMark(x: .value("Hour", point.hour), y: .value("Solar W", point.generation))
                        .foregroundStyle(Color.domainEnergy.gradient.opacity(0.4))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Hour", point.hour), y: .value("Solar W", point.generation))
                        .foregroundStyle(Color.domainEnergy)
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Hour", point.hour), y: .value("Load W", point.load))
                        .foregroundStyle(Color.domainHome)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5]))
                }
                .chartYAxisLabel("W")
                .frame(height: 160)
                HStack(spacing: Spacing.md) {
                    colorLegend(color: .domainEnergy, label: "Generation")
                    colorLegend(color: .domainHome, label: "Consumption")
                    Spacer()
                    Label(isExporting ? "Exporting to grid" : "Drawing from grid",
                          systemImage: isExporting ? "arrow.up.right" : "arrow.down.right")
                        .font(.prvioCaption())
                        .foregroundStyle(isExporting ? Color.healthThriving : Color.healthStressed)
                }
                .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Security").font(.prvioHeadline())
                HStack(spacing: Spacing.md) {
                    let onlineCams = cameras.filter { if case .device(let d) = $0.detail { return d.isOnline }; return false }.count
                    RiskBadge(label: "Cameras live", count: onlineCams, icon: "video.fill", tint: .domainHome)
                    RiskBadge(label: "Offline devices",
                              count: devices.filter { if case .device(let d) = $0.detail { return !d.isOnline }; return false }.count,
                              icon: "xmark.circle.fill", tint: .healthCritical)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Devices").font(.prvioHeadline())
                ForEach(devices.prefix(6)) { device in
                    HStack {
                        Image(systemName: device.kind.symbol)
                            .foregroundStyle(.domainHome).frame(width: 24)
                        Text(device.name).font(.prvioLabel())
                        Spacer()
                        if case .device(let d) = device.detail {
                            HStack(spacing: 4) {
                                if let w = d.powerWatts, w > 0 {
                                    Text(String(format: "%.0fW", w))
                                        .font(.prvioCaption()).foregroundStyle(.secondary)
                                }
                                Circle().fill(d.isOnline ? Color.healthThriving : Color.healthCritical)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    .padding(Spacing.md)
                    .liquidGlass(.raised, tint: .domainHome, interactive: false)
                }
            }

            if !insights.isEmpty {
                InsightFootnote(text: insights.first.map { $0.title + ". " + ($0.recommendation ?? "") }
                    ?? "PRVIO monitors all home devices and optimises energy usage automatically.",
                    tint: .domainHome)
            }
        }
    }

    private func colorLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 16, height: 3)
            Text(label).font(.prvioCaption()).foregroundStyle(.secondary)
        }
    }
}

private struct EnergyPoint {
    var hour: Int
    var generation: Double
    var load: Double
}
