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

// MARK: - Pond Analytics

public struct PondAnalyticsView: View {
    var twin: DigitalTwinEngine
    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var summary: PropertyAnalytics.PondSummary {
        PropertyAnalytics.pond(twin.entities)
    }
    private var oxygenPoints: [TimeSeriesPoint] {
        let seed = Double(abs(twin.entities.first { $0.kind == .pond }?.id.hashValue ?? 12_345) % 10_000) / 10_000.0
        let avg = summary.averageOxygenMgL
        return (0..<14).map { day in
            let wave = sin(Double(day) / 13.0 * .pi * 3.2 + seed * .pi * 2) * 1.1
            return TimeSeriesPoint(
                timestamp: .now.addingTimeInterval(Double(day - 14) * 86_400),
                value: min(11, max(3, avg + wave)))
        }
    }

    public var body: some View {
        AnalyticsScaffold(title: "Pond Analytics", tint: .domainPond) {
            let s = summary

            StatRow(stats: [
                .init(label: "Ponds", value: "\(s.pondCount)", icon: "drop.fill"),
                .init(label: "Fish",  value: "\(s.totalFishCount)", icon: "fish.fill"),
                .init(label: "Pumps", value: "\(s.pumpsOnline)", icon: "engine.combustion.fill"),
            ], tint: .domainPond)

            ChartCard(title: "Water chemistry", tint: .domainPond) {
                VStack(spacing: Spacing.sm) {
                    AnalyticsBar(label: "Avg pH", value: s.averagePH, range: 6.0...9.0, tint: .domainPond)
                    AnalyticsBar(label: "Avg O₂", value: s.averageOxygenMgL, range: 0...12, tint: .domainWater)
                    AnalyticsBar(label: "Temp", value: s.averageTempC, range: 0...35, tint: .domainGreenhouse, unit: "°C")
                }
            }

            ChartCard(title: "Dissolved O₂ trend (14 days)", tint: .domainWater) {
                Chart(oxygenPoints) { pt in
                    AreaMark(x: .value("Day", pt.timestamp), y: .value("O₂", pt.value))
                        .foregroundStyle(Color.domainWater.gradient.opacity(0.3))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Day", pt.timestamp), y: .value("O₂", pt.value))
                        .foregroundStyle(Color.domainWater)
                        .interpolationMethod(.catmullRom)
                    RuleMark(y: .value("Critical", 5))
                        .foregroundStyle(Color.healthCritical.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
                .chartYScale(domain: 0...12)
                .chartYAxisLabel("mg/L")
                .frame(height: 140)
            }

            HStack(spacing: Spacing.md) {
                RiskBadge(label: "Low O₂ ponds", count: s.lowOxygenCount,
                          icon: "exclamationmark.triangle.fill", tint: .healthStressed)
                RiskBadge(label: "Acidic ponds", count: s.acidicCount,
                          icon: "drop.fill", tint: .domainSecurity)
            }

            InsightFootnote(
                text: "PRVIO triggers aerators automatically when dissolved oxygen drops below 5 mg/L in any pond.",
                tint: .domainPond)
        }
    }
}

// MARK: - Garden Analytics

public struct GardenAnalyticsView: View {
    var twin: DigitalTwinEngine
    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var summary: PropertyAnalytics.GardenSummary {
        PropertyAnalytics.garden(twin.entities)
    }
    private var moistureItems: [(name: String, moisture: Double)] {
        twin.entities.filter { $0.kind == .garden }.compactMap { e in
            if case .garden(let g) = e.detail { return (e.name, g.soilMoisture) }
            return nil
        }
    }

    public var body: some View {
        AnalyticsScaffold(title: "Garden Analytics", tint: .domainGarden) {
            let s = summary

            StatRow(stats: [
                .init(label: "Garden beds", value: "\(s.totalBeds)", icon: "camera.macro"),
                .init(label: "Companions", value: "\(s.totalCompanionSpecies)", icon: "leaf.fill"),
                .init(label: "Mulched", value: "\(s.mulchedCount)/\(s.bedCount)", icon: "circle.fill"),
            ], tint: .domainGarden)

            if !moistureItems.isEmpty {
                ChartCard(title: "Soil moisture per bed", tint: .domainGarden) {
                    Chart {
                        ForEach(moistureItems, id: \.name) { item in
                            BarMark(x: .value("Bed", item.name),
                                    y: .value("Moisture %", item.moisture * 100))
                                .foregroundStyle(
                                    (item.moisture < 0.4 ? Color.healthCritical : Color.domainGarden).gradient)
                                .cornerRadius(6)
                        }
                        RuleMark(y: .value("Target", 55))
                            .foregroundStyle(Color.secondary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxisLabel("%")
                    .frame(height: 160)
                }
            }

            ChartCard(title: "Soil health summary", tint: .domainGarden) {
                VStack(spacing: Spacing.sm) {
                    AnalyticsBar(label: "Moisture", value: s.averageMoisture * 100,
                                 range: 0...100, tint: .domainWater, unit: "%")
                    AnalyticsBar(label: "pH", value: s.averagePH, range: 5.0...9.0, tint: .domainGarden)
                    AnalyticsBar(label: "Soil temp", value: s.averageSoilTempC,
                                 range: 5...40, tint: .domainOrchard, unit: "°C")
                }
            }

            HStack(spacing: Spacing.md) {
                RiskBadge(label: "Dry beds", count: s.dryBedCount,
                          icon: "sun.dust.fill", tint: .healthStressed)
                RiskBadge(label: "Not mulched", count: max(0, s.bedCount - s.mulchedCount),
                          icon: "circle.dashed", tint: .secondary)
            }

            if let next = s.nextWatering {
                InsightFootnote(
                    text: "Next watering: \(next.formatted(.dateTime.weekday().hour().minute())). PRVIO auto-schedules based on soil sensors and weather forecast.",
                    tint: .domainGarden)
            }
        }
    }
}

// MARK: - Greenhouse Analytics

public struct GreenhouseAnalyticsView: View {
    var twin: DigitalTwinEngine
    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var summary: PropertyAnalytics.GreenhouseSummary {
        PropertyAnalytics.greenhouse(twin.entities)
    }

    public var body: some View {
        AnalyticsScaffold(title: "Glasshouse Analytics", tint: .domainGreenhouse) {
            let s = summary

            StatRow(stats: [
                .init(label: "Zones", value: "\(s.totalZones)", icon: "square.grid.2x2.fill"),
                .init(label: "Crops", value: "\(s.uniqueCrops.count)", icon: "leaf.fill"),
                .init(label: "Lights on", value: "\(s.growLightsOnCount)/\(s.greenhouseCount)",
                      icon: "lightbulb.fill"),
            ], tint: .domainGreenhouse)

            ChartCard(title: "Aggregate climate", tint: .domainGreenhouse) {
                VStack(spacing: Spacing.sm) {
                    AnalyticsBar(label: "Temperature", value: s.averageTempC,
                                 range: 10...40, tint: .domainGreenhouse, unit: "°C")
                    AnalyticsBar(label: "Humidity", value: s.averageHumidity * 100,
                                 range: 0...100, tint: .domainWater, unit: "%")
                    AnalyticsBar(label: "CO₂", value: s.averageCO2Ppm, range: 400...2000,
                                 tint: s.co2SpikeCount > 0 ? .healthCritical : .domainGreenhouse, unit: " ppm")
                    AnalyticsBar(label: "Light", value: s.averageLightLux / 1000,
                                 range: 0...80, tint: .domainEnergy, unit: " klux")
                }
            }

            if !s.uniqueCrops.isEmpty {
                ChartCard(title: "Crop inventory (\(s.uniqueCrops.count) types)", tint: .domainGreenhouse) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(s.uniqueCrops, id: \.self) { crop in
                                Text(crop)
                                    .font(.prvioCaption())
                                    .padding(.horizontal, Spacing.sm + 2).padding(.vertical, 4)
                                    .liquidGlass(.raised, tint: .domainGreenhouse, interactive: false)
                            }
                        }
                    }
                }
            }

            HStack(spacing: Spacing.md) {
                RiskBadge(label: "Heat stress", count: s.heatStressCount,
                          icon: "thermometer.sun.fill", tint: .healthStressed)
                RiskBadge(label: "CO₂ spike", count: s.co2SpikeCount,
                          icon: "wind", tint: .domainSecurity)
            }

            if let next = s.nextHarvest {
                InsightFootnote(
                    text: "Harvest window opens \(next.formatted(.dateTime.month().day())). PRVIO sends a pick-time alert 24 h before optimal maturity.",
                    tint: .domainGreenhouse)
            }
        }
    }
}

// MARK: - Agriculture Analytics

public struct AgricultureAnalyticsView: View {
    var twin: DigitalTwinEngine
    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var summary: PropertyAnalytics.AgricultureSummary {
        PropertyAnalytics.agriculture(twin.entities)
    }

    public var body: some View {
        AnalyticsScaffold(title: "Field Analytics", tint: .domainAgriculture) {
            let s = summary

            StatRow(stats: [
                .init(label: "Fields", value: "\(s.fieldCount)", icon: "field.of.wheat"),
                .init(label: "Total area", value: String(format: "%.1f", s.totalAreaHa),
                      unit: "ha", icon: "rectangle.inset.filled"),
                .init(label: "Projected", value: String(format: "%.0f", s.projectedTotalTons),
                      unit: "t", icon: "chart.line.uptrend.xyaxis"),
            ], tint: .domainAgriculture)

            if !s.stageCounts.isEmpty {
                ChartCard(title: "Growth stage distribution", tint: .domainAgriculture) {
                    Chart(s.stageCounts, id: \.stage) { item in
                        SectorMark(angle: .value("Fields", item.count), innerRadius: .ratio(0.55))
                            .foregroundStyle(by: .value("Stage", item.stage))
                            .cornerRadius(4)
                    }
                    .chartLegend(.visible)
                    .frame(height: 180)
                }
            }

            ChartCard(title: "Total NPK reserves", tint: .domainAgriculture) {
                Chart {
                    BarMark(x: .value("Element", "N"), y: .value("kg", s.totalNPKkg.n))
                        .foregroundStyle(Color.healthThriving.gradient).cornerRadius(8)
                    BarMark(x: .value("Element", "P"), y: .value("kg", s.totalNPKkg.p))
                        .foregroundStyle(Color.domainWater.gradient).cornerRadius(8)
                    BarMark(x: .value("Element", "K"), y: .value("kg", s.totalNPKkg.k))
                        .foregroundStyle(Color.domainOrchard.gradient).cornerRadius(8)
                }
                .frame(height: 130)
            }

            ChartCard(title: "Field averages", tint: .domainAgriculture) {
                VStack(spacing: Spacing.sm) {
                    AnalyticsBar(label: "Soil moisture", value: s.averageSoilMoisture * 100,
                                 range: 0...100, tint: .domainWater, unit: "%")
                    AnalyticsBar(label: "Yield forecast", value: s.averageYieldForecastTha,
                                 range: 0...15, tint: .healthThriving, unit: " t/ha")
                }
            }

            HStack(spacing: Spacing.md) {
                RiskBadge(label: "Drought stress", count: s.droughtStressCount,
                          icon: "sun.dust.fill", tint: .healthStressed)
                RiskBadge(label: "N deficiency", count: s.nDeficiencyCount,
                          icon: "leaf.fill", tint: .domainSecurity)
            }

            InsightFootnote(
                text: "Projected harvest: \(String(format: "%.0f", s.projectedTotalTons)) t across \(String(format: "%.1f", s.totalAreaHa)) ha. PRVIO adjusts irrigation and fertiliser plans automatically.",
                tint: .domainAgriculture)
        }
    }
}

// MARK: - Shared analytics progress bar

private struct AnalyticsBar: View {
    var label: String
    var value: Double
    var range: ClosedRange<Double>
    var tint: Color
    var unit: String = ""

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / span))
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(label)
                .font(.prvioCaption()).foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1)).frame(height: 8)
                    Capsule().fill(tint.gradient).frame(width: geo.size.width * fraction, height: 8)
                }
            }
            .frame(height: 8)
            Text(String(format: "%.1f", value) + unit)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
        }
    }
}

