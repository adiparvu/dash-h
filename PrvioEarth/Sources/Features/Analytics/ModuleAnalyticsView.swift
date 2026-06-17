//
//  ModuleAnalyticsView.swift
//  PRVIO EARTH
//
//  Analytics deep-dives for Smart Forest and Smart Orchard. Liquid Glass
//  chart cards over the twin: carbon & biomass roll-ups, species mix, yield
//  forecasting and harvest planning — all computed from the live entities via
//  PropertyAnalytics. Reached from the module surfaces.
//

import SwiftUI
import Charts

// MARK: - Forest Analytics

public struct ForestAnalyticsView: View {
    var twin: DigitalTwinEngine
    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var summary: PropertyAnalytics.ForestSummary {
        PropertyAnalytics.forest(twin.entities)
    }

    public var body: some View {
        AnalyticsScaffold(title: "Forest Analytics", tint: .domainForest) {
            let s = summary

            StatRow(stats: [
                .init(label: "Trees", value: "\(s.treeCount)", icon: "tree.fill"),
                .init(label: "Carbon", value: "\(Int(s.totalCarbonKg))", unit: "kg", icon: "leaf.fill"),
                .init(label: "Avg Height", value: String(format: "%.1f", s.averageHeightM), unit: "m", icon: "arrow.up.to.line")
            ], tint: .domainForest)

            ChartCard(title: "Carbon stored by species", tint: .domainForest) {
                Chart(s.carbonBySpecies, id: \.species) { item in
                    BarMark(x: .value("Carbon", item.carbonKg), y: .value("Species", item.species))
                        .foregroundStyle(Color.domainForest.gradient)
                        .cornerRadius(6)
                        .annotation(position: .trailing) {
                            Text("\(Int(item.carbonKg))kg").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                }
                .frame(height: CGFloat(max(s.carbonBySpecies.count, 1) * 38 + 20))
            }

            ChartCard(title: "Species distribution", tint: .domainForest) {
                Chart(s.speciesCounts, id: \.species) { item in
                    SectorMark(angle: .value("Count", item.count), innerRadius: .ratio(0.58), angularInset: 2)
                        .foregroundStyle(by: .value("Species", item.species))
                        .cornerRadius(4)
                }
                .frame(height: 200)
            }

            HStack(spacing: Spacing.md) {
                RiskBadge(label: "Drought risk", count: s.droughtRiskCount, icon: "sun.dust.fill", tint: .healthStressed)
                RiskBadge(label: "Pest detected", count: s.pestCount, icon: "ant.fill", tint: .domainSecurity)
            }

            InsightFootnote(text: "Your forest offsets roughly \(String(format: "%.1f", s.carEquivalent)) cars' worth of CO₂ per year.",
                            tint: .domainForest)
        }
    }
}

// MARK: - Orchard Analytics

public struct OrchardAnalyticsView: View {
    var twin: DigitalTwinEngine
    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var summary: PropertyAnalytics.OrchardSummary {
        PropertyAnalytics.orchard(twin.entities)
    }

    public var body: some View {
        AnalyticsScaffold(title: "Orchard Analytics", tint: .domainOrchard) {
            let s = summary
            let forecast = PropertyAnalytics.yieldForecast(s)

            StatRow(stats: [
                .init(label: "Expected", value: "\(Int(s.totalExpectedYieldKg))", unit: "kg", icon: "scalemass.fill"),
                .init(label: "vs Last", value: String(format: "%+.0f", s.yieldDeltaPercent), unit: "%", icon: s.yieldDeltaPercent >= 0 ? "arrow.up.right" : "arrow.down.right"),
                .init(label: "Irrigated", value: "\(s.irrigatedCount)/\(s.treeCount)", icon: "spigot.fill")
            ], tint: .domainOrchard)

            ChartCard(title: "Yield forecast (season)", tint: .domainOrchard) {
                Chart(forecast) { point in
                    AreaMark(x: .value("Month", point.timestamp, unit: .month), y: .value("Yield", point.value))
                        .foregroundStyle(Color.domainOrchard.gradient.opacity(0.35))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Month", point.timestamp, unit: .month), y: .value("Yield", point.value))
                        .foregroundStyle(Color.domainOrchard)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Month", point.timestamp, unit: .month), y: .value("Yield", point.value))
                        .foregroundStyle(Color.domainOrchard)
                }
                .frame(height: 160)
            }

            ChartCard(title: "Expected vs last harvest by species", tint: .domainOrchard) {
                Chart {
                    ForEach(s.yieldBySpecies, id: \.species) { item in
                        BarMark(x: .value("Species", item.species), y: .value("kg", item.lastKg))
                            .foregroundStyle(Color.domainOrchard.opacity(0.4))
                            .position(by: .value("Type", "Last"))
                        BarMark(x: .value("Species", item.species), y: .value("kg", item.expectedKg))
                            .foregroundStyle(Color.domainOrchard.gradient)
                            .position(by: .value("Type", "Expected"))
                    }
                }
                .frame(height: 180)
            }

            ChartCard(title: "Phenophase distribution", tint: .domainOrchard) {
                Chart(s.phenophaseCounts, id: \.phase) { item in
                    BarMark(x: .value("Phase", item.phase), y: .value("Trees", item.count))
                        .foregroundStyle(Color.domainGarden.gradient)
                        .cornerRadius(6)
                }
                .frame(height: 140)
            }

            if let next = s.nextHarvest {
                InsightFootnote(text: "Next harvest window opens \(next.formatted(.dateTime.month().day())). PRVIO will draft a picking schedule a week before.",
                                tint: .domainOrchard)
            }
        }
    }
}

