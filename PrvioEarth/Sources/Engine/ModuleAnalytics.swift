//
//  ModuleAnalytics.swift
//  PRVIO EARTH
//
//  Deep analytics roll-ups for the Smart Forest and Smart Orchard modules,
//  computed purely from the live twin entities (TreeProfile / OrchardProfile).
//  These power the analytics deep-dive screens — carbon & biomass totals,
//  species mix, growth and yield, harvest timeline and a yield forecast.
//

import Foundation

public extension PropertyAnalytics {

    // MARK: - Forest

    struct ForestSummary: Sendable {
        public var treeCount: Int
        public var totalCarbonKg: Double
        public var totalBiomassKg: Double
        public var averageHeightM: Double
        public var speciesCounts: [(species: String, count: Int)]
        public var droughtRiskCount: Int       // low soil moisture
        public var pestCount: Int
        public var carbonBySpecies: [(species: String, carbonKg: Double)]

        /// Equivalent passenger-car emissions offset per year (rough EPA factor:
        /// ~4,600 kg CO₂/car/yr; carbon → CO₂ ×3.67).
        public var carEquivalent: Double { (totalCarbonKg * 3.67) / 4600 }
    }

    static func forest(_ entities: [PropertyEntity]) -> ForestSummary {
        let trees = entities.compactMap { e -> (PropertyEntity, TreeProfile)? in
            if case .tree(let t) = e.detail { return (e, t) }
            return nil
        }

        var carbon = 0.0, biomass = 0.0, height = 0.0
        var bySpeciesCount: [String: Int] = [:]
        var bySpeciesCarbon: [String: Double] = [:]
        var drought = 0, pests = 0

        for (_, t) in trees {
            carbon += t.carbonStorageKg
            biomass += t.biomassKg
            height += t.heightMeters
            bySpeciesCount[t.species, default: 0] += 1
            bySpeciesCarbon[t.species, default: 0] += t.carbonStorageKg
            if t.soilMoisture < 0.45 { drought += 1 }
            if t.pestDetected { pests += 1 }
        }

        return ForestSummary(
            treeCount: trees.count,
            totalCarbonKg: carbon,
            totalBiomassKg: biomass,
            averageHeightM: trees.isEmpty ? 0 : height / Double(trees.count),
            speciesCounts: bySpeciesCount.map { ($0.key, $0.value) }.sorted { $0.count > $1.count },
            droughtRiskCount: drought,
            pestCount: pests,
            carbonBySpecies: bySpeciesCarbon.map { ($0.key, $0.value) }.sorted { $0.carbonKg > $1.carbonKg })
    }

    // MARK: - Orchard

    struct OrchardSummary: Sendable {
        public var treeCount: Int
        public var totalExpectedYieldKg: Double
        public var totalLastHarvestKg: Double
        public var yieldBySpecies: [(species: String, expectedKg: Double, lastKg: Double)]
        public var phenophaseCounts: [(phase: String, count: Int)]
        public var nextHarvest: Date?
        public var irrigatedCount: Int

        /// Percentage change vs. the last harvest (yield trajectory).
        public var yieldDeltaPercent: Double {
            guard totalLastHarvestKg > 0 else { return 0 }
            return (totalExpectedYieldKg - totalLastHarvestKg) / totalLastHarvestKg * 100
        }
    }

    static func orchard(_ entities: [PropertyEntity]) -> OrchardSummary {
        let trees = entities.compactMap { e -> OrchardProfile? in
            if case .orchard(let o) = e.detail { return o }
            return nil
        }

        var expected = 0.0, last = 0.0, irrigated = 0
        var byPhase: [String: Int] = [:]
        var bySpeciesExpected: [String: Double] = [:]
        var bySpeciesLast: [String: Double] = [:]

        for o in trees {
            expected += o.expectedYieldKg
            last += o.lastHarvestKg
            if o.irrigationActive { irrigated += 1 }
            byPhase[o.phenophase.rawValue.capitalized, default: 0] += 1
            bySpeciesExpected[o.species, default: 0] += o.expectedYieldKg
            bySpeciesLast[o.species, default: 0] += o.lastHarvestKg
        }

        let yieldBySpecies = bySpeciesExpected.keys.map { sp in
            (sp, bySpeciesExpected[sp] ?? 0, bySpeciesLast[sp] ?? 0)
        }.sorted { $0.1 > $1.1 }

        return OrchardSummary(
            treeCount: trees.count,
            totalExpectedYieldKg: expected,
            totalLastHarvestKg: last,
            yieldBySpecies: yieldBySpecies,
            phenophaseCounts: byPhase.map { ($0.key, $0.value) }.sorted { $0.count > $1.count },
            nextHarvest: trees.map(\.nextHarvest).min(),
            irrigatedCount: irrigated)
    }

    /// A monthly yield projection for the orchard across a season, smoothing
    /// from the last harvest toward the expected yield with a seasonal curve.
    static func yieldForecast(_ summary: OrchardSummary, months: Int = 6) -> [TimeSeriesPoint] {
        let start = Date.now
        let target = summary.totalExpectedYieldKg
        let base = summary.totalLastHarvestKg
        return (0..<months).map { m in
            let t = Double(m) / Double(max(months - 1, 1))
            // Smooth S-curve from base → target, peaking near harvest.
            let curve = base + (target - base) * (t * t * (3 - 2 * t))
            return TimeSeriesPoint(
                timestamp: Calendar.current.date(byAdding: .month, value: m, to: start) ?? start,
                value: curve)
        }
    }
}
