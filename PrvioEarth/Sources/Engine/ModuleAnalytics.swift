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
            let curve = base + (target - base) * (t * t * (3 - 2 * t))
            return TimeSeriesPoint(
                timestamp: Calendar.current.date(byAdding: .month, value: m, to: start) ?? start,
                value: curve)
        }
    }

    // MARK: - Pond

    struct PondSummary: Sendable {
        public var pondCount: Int
        public var averagePH: Double
        public var averageOxygenMgL: Double
        public var averageTempC: Double
        public var totalFishCount: Int
        public var pumpsOnline: Int
        public var lowOxygenCount: Int    // O₂ < 5 mg/L
        public var acidicCount: Int       // pH < 6.5
    }

    static func pond(_ entities: [PropertyEntity]) -> PondSummary {
        let profiles = entities.compactMap { e -> PondProfile? in
            if case .pond(let p) = e.detail { return p }; return nil
        }
        guard !profiles.isEmpty else {
            return PondSummary(pondCount: 0, averagePH: 7, averageOxygenMgL: 8,
                               averageTempC: 18, totalFishCount: 0, pumpsOnline: 0,
                               lowOxygenCount: 0, acidicCount: 0)
        }
        let n = Double(profiles.count)
        return PondSummary(
            pondCount: profiles.count,
            averagePH: profiles.map(\.pH).reduce(0, +) / n,
            averageOxygenMgL: profiles.map(\.dissolvedOxygenMgL).reduce(0, +) / n,
            averageTempC: profiles.map(\.waterTempC).reduce(0, +) / n,
            totalFishCount: profiles.map(\.fishCount).reduce(0, +),
            pumpsOnline: profiles.map(\.pumpsOnline).reduce(0, +),
            lowOxygenCount: profiles.filter { $0.dissolvedOxygenMgL < 5 }.count,
            acidicCount: profiles.filter { $0.pH < 6.5 }.count)
    }

    // MARK: - Garden

    struct GardenSummary: Sendable {
        public var bedCount: Int
        public var totalBeds: Int         // beds across all garden entities
        public var averageMoisture: Double
        public var averagePH: Double
        public var averageSoilTempC: Double
        public var dryBedCount: Int       // moisture < 0.4
        public var mulchedCount: Int
        public var totalCompanionSpecies: Int
        public var nextWatering: Date?
    }

    static func garden(_ entities: [PropertyEntity]) -> GardenSummary {
        let profiles = entities.compactMap { e -> GardenProfile? in
            if case .garden(let g) = e.detail { return g }; return nil
        }
        guard !profiles.isEmpty else {
            return GardenSummary(bedCount: 0, totalBeds: 0, averageMoisture: 0.5,
                                 averagePH: 6.8, averageSoilTempC: 18, dryBedCount: 0,
                                 mulchedCount: 0, totalCompanionSpecies: 0, nextWatering: nil)
        }
        let n = Double(profiles.count)
        let companions = Set(profiles.flatMap(\.companions))
        return GardenSummary(
            bedCount: profiles.count,
            totalBeds: profiles.map(\.beds.count).reduce(0, +),
            averageMoisture: profiles.map(\.soilMoisture).reduce(0, +) / n,
            averagePH: profiles.map(\.soilPH).reduce(0, +) / n,
            averageSoilTempC: profiles.map(\.soilTemperatureC).reduce(0, +) / n,
            dryBedCount: profiles.filter { $0.soilMoisture < 0.4 }.count,
            mulchedCount: profiles.filter(\.mulched).count,
            totalCompanionSpecies: companions.count,
            nextWatering: profiles.map(\.nextWatering).min())
    }

    // MARK: - Greenhouse

    struct GreenhouseSummary: Sendable {
        public var greenhouseCount: Int
        public var totalZones: Int
        public var averageTempC: Double
        public var averageHumidity: Double
        public var averageCO2Ppm: Double
        public var averageLightLux: Double
        public var growLightsOnCount: Int
        public var ventilationOnCount: Int
        public var uniqueCrops: [String]
        public var nextHarvest: Date?
        public var heatStressCount: Int   // temp > 35°C
        public var co2SpikeCount: Int     // CO₂ > 1500 ppm
    }

    static func greenhouse(_ entities: [PropertyEntity]) -> GreenhouseSummary {
        let profiles = entities.compactMap { e -> GreenhouseProfile? in
            if case .greenhouse(let g) = e.detail { return g }; return nil
        }
        guard !profiles.isEmpty else {
            return GreenhouseSummary(greenhouseCount: 0, totalZones: 0, averageTempC: 22,
                                     averageHumidity: 0.65, averageCO2Ppm: 800,
                                     averageLightLux: 20_000, growLightsOnCount: 0,
                                     ventilationOnCount: 0, uniqueCrops: [],
                                     nextHarvest: nil, heatStressCount: 0, co2SpikeCount: 0)
        }
        let n = Double(profiles.count)
        var seen = Set<String>()
        let crops = profiles.flatMap(\.crops).filter { seen.insert($0).inserted }
        return GreenhouseSummary(
            greenhouseCount: profiles.count,
            totalZones: profiles.map(\.zones).reduce(0, +),
            averageTempC: profiles.map(\.temperatureC).reduce(0, +) / n,
            averageHumidity: profiles.map(\.humidity).reduce(0, +) / n,
            averageCO2Ppm: profiles.map(\.co2Ppm).reduce(0, +) / n,
            averageLightLux: profiles.map(\.lightLux).reduce(0, +) / n,
            growLightsOnCount: profiles.filter(\.growLightsOn).count,
            ventilationOnCount: profiles.filter(\.ventilationOn).count,
            uniqueCrops: crops,
            nextHarvest: profiles.compactMap(\.nextHarvest).min(),
            heatStressCount: profiles.filter { $0.temperatureC > 35 }.count,
            co2SpikeCount: profiles.filter { $0.co2Ppm > 1500 }.count)
    }

    // MARK: - Agriculture

    struct AgricultureSummary: Sendable {
        public var fieldCount: Int
        public var totalAreaHa: Double
        public var averageSoilMoisture: Double
        public var averageYieldForecastTha: Double
        public var stageCounts: [(stage: String, count: Int)]
        public var totalNPKkg: (n: Double, p: Double, k: Double)
        public var droughtStressCount: Int  // moisture < 0.30
        public var nDeficiencyCount: Int    // N < 60 kg/ha
        public var projectedTotalTons: Double { totalAreaHa * averageYieldForecastTha }
    }

    static func agriculture(_ entities: [PropertyEntity]) -> AgricultureSummary {
        let profiles = entities.compactMap { e -> AgricultureProfile? in
            if case .agriculture(let a) = e.detail { return a }; return nil
        }
        guard !profiles.isEmpty else {
            return AgricultureSummary(fieldCount: 0, totalAreaHa: 0, averageSoilMoisture: 0.5,
                                      averageYieldForecastTha: 0, stageCounts: [],
                                      totalNPKkg: (0, 0, 0), droughtStressCount: 0, nDeficiencyCount: 0)
        }
        let n = Double(profiles.count)
        var stageMap: [String: Int] = [:]
        var totalN = 0.0, totalP = 0.0, totalK = 0.0
        for p in profiles {
            stageMap[p.growthStage.rawValue.capitalized, default: 0] += 1
            totalN += p.npk.nitrogen * p.fieldAreaHa
            totalP += p.npk.phosphorus * p.fieldAreaHa
            totalK += p.npk.potassium * p.fieldAreaHa
        }
        return AgricultureSummary(
            fieldCount: profiles.count,
            totalAreaHa: profiles.map(\.fieldAreaHa).reduce(0, +),
            averageSoilMoisture: profiles.map(\.soilMoisture).reduce(0, +) / n,
            averageYieldForecastTha: profiles.map(\.yieldForecastTha).reduce(0, +) / n,
            stageCounts: stageMap.map { ($0.key, $0.value) }.sorted { $0.count > $1.count },
            totalNPKkg: (totalN, totalP, totalK),
            droughtStressCount: profiles.filter { $0.soilMoisture < 0.30 }.count,
            nDeficiencyCount: profiles.filter { $0.npk.nitrogen < 60 }.count)
    }
}
