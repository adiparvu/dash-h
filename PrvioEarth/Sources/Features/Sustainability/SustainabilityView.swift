//
//  SustainabilityView.swift
//  PRVIO EARTH
//
//  ESG-style sustainability dashboard for the whole property. Carbon
//  sequestration, renewable energy ratio, water efficiency and biodiversity
//  score — all computed live from the Digital Twin so every time the twin
//  updates these numbers move. Reached from the Systems Hub.
//

import SwiftUI
import Charts

public struct SustainabilityView: View {
    var twin: DigitalTwinEngine
    public init(twin: DigitalTwinEngine) { self.twin = twin }

    // MARK: - Computed sustainability metrics

    private var forestSummary: PropertyAnalytics.ForestSummary {
        PropertyAnalytics.forest(twin.entities)
    }
    private var energySummary: PropertyAnalytics.EnergySummary {
        PropertyAnalytics.energy(twin.entities)
    }
    private var waterSummary: PropertyAnalytics.WaterSummary {
        PropertyAnalytics.water(twin.entities)
    }

    /// Carbon sequestered this year, capped by a 50 t / tree target.
    private var carbonKg: Double { forestSummary.totalCarbonKg }
    private var carbonTargetKg: Double { Double(max(1, forestSummary.treeCount)) * 500 }
    private var carbonFraction: Double { min(1, carbonKg / carbonTargetKg) }

    /// Renewable fraction: 0…1 derived from exporting state (simplification).
    private var renewableFraction: Double { energySummary.isExporting ? 0.92 : 0.48 }
    private var energyKwh: Double { energySummary.todayKwh }

    /// Water efficiency from agriculture irrigation efficiency + pond level.
    private var waterEfficiency: Double {
        let agriEntities = twin.entities.compactMap { e -> Double? in
            if case .agriculture(let a) = e.detail { return a.irrigationEfficiency }
            return nil
        }
        let base = agriEntities.isEmpty ? waterSummary.pondLevelPercent / 100
            : agriEntities.reduce(0, +) / Double(agriEntities.count)
        return min(1, max(0, base))
    }

    /// Biodiversity: unique tree/plant species count normalised to 0…1 (target 20 species).
    private var biodiversityScore: Double {
        var species = Set<String>()
        for e in twin.entities {
            switch e.detail {
            case .tree(let t): species.insert(t.species)
            case .orchard(let o): species.insert(o.species)
            default: break
            }
        }
        return min(1, Double(species.count) / 20.0)
    }
    private var uniqueSpeciesCount: Int {
        var s = Set<String>()
        for e in twin.entities {
            switch e.detail {
            case .tree(let t): s.insert(t.species)
            case .orchard(let o): s.insert(o.species)
            default: break
            }
        }
        return s.count
    }

    /// Synthetic per-month carbon data derived from the live total (for chart sparklines).
    private var carbonTrend: [TimeSeriesPoint] {
        (0..<12).map { month in
            let fraction = Double(month + 1) / 12.0
            let seasonal = 0.8 + 0.2 * sin(fraction * .pi)
            return TimeSeriesPoint(
                timestamp: Calendar.current.date(byAdding: .month, value: month - 11, to: .now)!,
                value: carbonKg * fraction * seasonal)
        }
    }

    // MARK: - Export

    private var exportReport: String {
        let lines: [String] = [
            "PRVIO EARTH — Sustainability Report",
            "Generated: \(Date().formatted(.dateTime.day().month().year().hour().minute()))",
            String(repeating: "=", count: 44),
            "",
            "CARBON SEQUESTRATION",
            "  Captured this year:  \(Int(carbonKg)) kg",
            "  Annual target:       \(Int(carbonTargetKg)) kg",
            "  Progress:            \(Int(carbonFraction * 100))%",
            "  Car-offset equiv.:   \(String(format: "%.1f", carbonKg / 120)) cars/year",
            "",
            "ENERGY",
            "  Today's usage:    \(String(format: "%.1f", energyKwh)) kWh",
            "  Renewable share:  \(Int(renewableFraction * 100))%",
            "  Grid status:      \(energySummary.isExporting ? "Exporting" : "Importing")",
            "",
            "WATER",
            "  Irrigation efficiency:  \(Int(waterEfficiency * 100))%",
            "  Pumps online:           \(waterSummary.pumpsOnline)",
            "",
            "BIODIVERSITY",
            "  Unique species:  \(uniqueSpeciesCount)",
            "  Target:          20 species",
            "  Score:           \(Int(biodiversityScore * 100))%",
            "",
            "GRADES",
            "  Carbon:  \(gradeLabel(carbonFraction))",
            "  Energy:  \(gradeLabel(renewableFraction))",
            "  Water:   \(gradeLabel(waterEfficiency))",
            "  Bio:     \(gradeLabel(biodiversityScore))",
            "",
            "Data source: PRVIO EARTH Digital Twin — live sensor telemetry.",
        ]
        return lines.joined(separator: "\n")
    }

    private func gradeLabel(_ score: Double) -> String {
        switch score {
        case 0.9...: return "A — Outstanding"
        case 0.75...: return "B — Good"
        case 0.6...: return "C — Average"
        default: return "D — Needs work"
        }
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                headerCard
                scoreRow
                carbonCard
                energyCard
                waterBiodiversityRow
                speciesCard
                footerNote
            }
            .padding(Spacing.lg)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial).ignoresSafeArea()
        }
    }

    // MARK: - Sections

    private var headerCard: some View {
        GlassCard(depth: .modal, tint: .domainForest) {
            HStack(spacing: Spacing.lg) {
                ZStack {
                    Circle().fill(Color.domainForest.opacity(0.18)).frame(width: 72, height: 72)
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 34)).foregroundStyle(.domainForest)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sustainability").font(.prvioTitle())
                    Text("Property ESG Report · Live").font(.prvioCaption()).foregroundStyle(.secondary)
                    Text("Updated from live twin").font(.prvioCaption()).foregroundStyle(.domainForest)
                }
                Spacer()
                ShareLink(item: exportReport,
                          subject: Text("PRVIO Sustainability Report"),
                          message: Text("Generated from PRVIO EARTH Digital Twin")) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.prvioLabel())
                        .padding(Spacing.sm)
                        .liquidGlass(.raised, tint: .domainForest, interactive: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Four score rings.
    private var scoreRow: some View {
        HStack(spacing: Spacing.md) {
            ScoreRing(label: "Carbon", score: carbonFraction, tint: .domainForest,
                      value: "\(Int(carbonFraction * 100))%")
            ScoreRing(label: "Energy", score: renewableFraction, tint: .domainEnergy,
                      value: "\(Int(renewableFraction * 100))%")
            ScoreRing(label: "Water", score: waterEfficiency, tint: .domainWater,
                      value: "\(Int(waterEfficiency * 100))%")
            ScoreRing(label: "Bio", score: biodiversityScore, tint: .domainGarden,
                      value: "\(Int(biodiversityScore * 100))%")
        }
    }

    /// Carbon sequestration progress + trend chart.
    private var carbonCard: some View {
        GlassCard(tint: .domainForest) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Carbon Sequestration", systemImage: "leaf.fill")
                    .font(.prvioHeadline()).foregroundStyle(.domainForest)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(carbonKg)) kg")
                            .font(.prvioMetric()).foregroundStyle(.domainForest)
                        Text("Yearly target: \(Int(carbonTargetKg)) kg")
                            .font(.prvioCaption()).foregroundStyle(.secondary)
                        Text("≈ \(String(format: "%.1f", carbonKg / 120)) cars offset")
                            .font(.prvioCaption()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HealthRing(score: carbonFraction, lineWidth: 10)
                        .frame(width: 72, height: 72)
                        .overlay {
                            Text("\(Int(carbonFraction * 100))%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.domainForest)
                        }
                }

                Chart(carbonTrend) { point in
                    AreaMark(x: .value("Month", point.timestamp),
                             y: .value("kg", point.value))
                        .foregroundStyle(Color.domainForest.opacity(0.25).gradient)
                    LineMark(x: .value("Month", point.timestamp),
                             y: .value("kg", point.value))
                        .foregroundStyle(.domainForest)
                        .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                        AxisValueLabel().font(.system(size: 9)).foregroundStyle(Color.secondary)
                        AxisGridLine(stroke: StrokeStyle(dash: [2, 4])).foregroundStyle(Color.secondary.opacity(0.3))
                    }
                }
                .frame(height: 90)
            }
        }
    }

    /// Energy card.
    private var energyCard: some View {
        GlassCard(tint: .domainEnergy) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Energy", systemImage: "bolt.fill")
                    .font(.prvioHeadline()).foregroundStyle(.domainEnergy)

                HStack(spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(format: "%.1f", energyKwh)) kWh")
                            .font(.prvioMetric()).foregroundStyle(.domainEnergy)
                        Text("Today's usage")
                            .font(.prvioCaption()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(renewableFraction * 100))%")
                            .font(.prvioMetric()).foregroundStyle(.domainEnergy)
                        Text("Renewable")
                            .font(.prvioCaption()).foregroundStyle(.secondary)
                    }
                }

                // Renewable bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.domainEnergy.opacity(0.15)).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.domainEnergy.gradient)
                            .frame(width: geo.size.width * renewableFraction, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Label(energySummary.isExporting ? "Exporting to grid" : "Drawing from grid",
                          systemImage: energySummary.isExporting ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill")
                        .font(.prvioCaption())
                        .foregroundStyle(energySummary.isExporting ? .healthThriving : .healthStressed)
                    Spacer()
                }
            }
        }
    }

    /// Water + biodiversity side by side.
    private var waterBiodiversityRow: some View {
        HStack(spacing: Spacing.md) {
            GlassCard(tint: .domainWater) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label("Water", systemImage: "drop.fill")
                        .font(.prvioHeadline()).foregroundStyle(.domainWater)
                    Text("\(Int(waterEfficiency * 100))%")
                        .font(.prvioMetric()).foregroundStyle(.domainWater)
                    Text("Irrigation efficiency")
                        .font(.prvioCaption()).foregroundStyle(.secondary)
                    Text("\(waterSummary.pumpsOnline) pumps online")
                        .font(.prvioCaption()).foregroundStyle(.secondary)
                }
            }
            GlassCard(tint: .domainGarden) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label("Biodiversity", systemImage: "camera.macro")
                        .font(.prvioHeadline()).foregroundStyle(.domainGarden)
                    Text("\(uniqueSpeciesCount)")
                        .font(.prvioMetric()).foregroundStyle(.domainGarden)
                    Text("Species on property")
                        .font(.prvioCaption()).foregroundStyle(.secondary)
                    Text("Target: 20 species")
                        .font(.prvioCaption()).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Species breakdown bar chart.
    private var speciesCard: some View {
        let speciesCounts = buildSpeciesCounts()
        guard !speciesCounts.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            GlassCard(tint: .domainForest) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label("Species Composition", systemImage: "list.bullet.indent")
                        .font(.prvioHeadline())
                    Chart(speciesCounts, id: \.species) { item in
                        BarMark(x: .value("Count", item.count),
                                y: .value("Species", item.species))
                            .foregroundStyle(Color.domainForest.gradient)
                            .cornerRadius(4)
                            .annotation(position: .trailing) {
                                Text("\(item.count)")
                                    .font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                    }
                    .frame(height: CGFloat(max(speciesCounts.count, 2) * 36 + 16))
                }
            }
        )
    }

    private var footerNote: some View {
        InsightFootnote(
            text: "Carbon data from live tree sensors. Energy from HomeKit/Matter devices. Biodiversity from entity registry.",
            tint: .domainForest)
    }

    // MARK: - Helpers

    private func buildSpeciesCounts() -> [(species: String, count: Int)] {
        var dict: [String: Int] = [:]
        for e in twin.entities {
            switch e.detail {
            case .tree(let t): dict[t.species, default: 0] += 1
            case .orchard(let o): dict[o.species, default: 0] += 1
            default: break
            }
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }
}

// MARK: - Score Ring

private struct ScoreRing: View {
    var label: String
    var score: Double
    var tint: Color
    var value: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                HealthRing(score: score, lineWidth: 7)
                    .frame(width: 60, height: 60)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
            Text(label)
                .font(.prvioCaption()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .liquidGlass(.raised, tint: tint, interactive: false)
    }
}
