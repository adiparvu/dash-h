//
//  ModuleProfiles.swift
//  PRVIO EARTH
//
//  Rich, module-specific profiles carried by PropertyEntity.detail. These
//  mirror the data captured by TreeScope, SeeTree, OpenFarm and FarmBot —
//  but unified under one Apple-native model.
//

import Foundation

// MARK: - Smart Forest

public struct TreeProfile: Codable, Hashable, Sendable {
    public var species: String
    public var ageYears: Int
    public var heightMeters: Double
    public var trunkDiameterCm: Double
    public var growthRateCmPerYear: Double
    public var carbonStorageKg: Double
    public var biomassKg: Double
    public var pestDetected: Bool
    public var soilMoisture: Double      // 0...1
    public var soilPH: Double

    public init(species: String, ageYears: Int, heightMeters: Double, trunkDiameterCm: Double,
                growthRateCmPerYear: Double, carbonStorageKg: Double, biomassKg: Double,
                pestDetected: Bool = false, soilMoisture: Double, soilPH: Double) {
        self.species = species; self.ageYears = ageYears; self.heightMeters = heightMeters
        self.trunkDiameterCm = trunkDiameterCm; self.growthRateCmPerYear = growthRateCmPerYear
        self.carbonStorageKg = carbonStorageKg; self.biomassKg = biomassKg
        self.pestDetected = pestDetected; self.soilMoisture = soilMoisture; self.soilPH = soilPH
    }
}

// MARK: - Smart Orchard

public struct OrchardProfile: Codable, Hashable, Sendable {
    public enum Phenophase: String, Codable, Sendable { case dormant, budding, flowering, fruiting, ripening, harvest }
    public var species: String
    public var phenophase: Phenophase
    public var expectedYieldKg: Double
    public var lastHarvestKg: Double
    public var nextHarvest: Date
    public var irrigationActive: Bool
    public var nextFertilization: Date
    public var nextPruning: Date

    public init(species: String, phenophase: Phenophase, expectedYieldKg: Double, lastHarvestKg: Double,
                nextHarvest: Date, irrigationActive: Bool, nextFertilization: Date, nextPruning: Date) {
        self.species = species; self.phenophase = phenophase
        self.expectedYieldKg = expectedYieldKg; self.lastHarvestKg = lastHarvestKg
        self.nextHarvest = nextHarvest; self.irrigationActive = irrigationActive
        self.nextFertilization = nextFertilization; self.nextPruning = nextPruning
    }
}

// MARK: - Smart Pond

public struct PondProfile: Codable, Hashable, Sendable {
    public var waterTempC: Double
    public var pH: Double
    public var dissolvedOxygenMgL: Double
    public var ammoniaMgL: Double
    public var nitrateMgL: Double
    public var waterLevelPercent: Double
    public var fishCount: Int
    public var pumpsOnline: Int
    public var uvSterilizerOn: Bool

    public init(waterTempC: Double, pH: Double, dissolvedOxygenMgL: Double, ammoniaMgL: Double,
                nitrateMgL: Double, waterLevelPercent: Double, fishCount: Int, pumpsOnline: Int,
                uvSterilizerOn: Bool) {
        self.waterTempC = waterTempC; self.pH = pH
        self.dissolvedOxygenMgL = dissolvedOxygenMgL; self.ammoniaMgL = ammoniaMgL
        self.nitrateMgL = nitrateMgL; self.waterLevelPercent = waterLevelPercent
        self.fishCount = fishCount; self.pumpsOnline = pumpsOnline
        self.uvSterilizerOn = uvSterilizerOn
    }
}

// MARK: - Smart Home / Devices

public struct DeviceProfile: Codable, Hashable, Sendable {
    public enum Protocolo: String, Codable, CaseIterable, Sendable {
        case matter, homeKit, zigbee, zWave, mqtt, thread, wifi
    }
    public var protocolType: Protocolo
    public var isOnline: Bool
    public var isOn: Bool
    public var powerWatts: Double?
    public var batteryPercent: Double?
    public var firmware: String

    public init(protocolType: Protocolo, isOnline: Bool, isOn: Bool, powerWatts: Double? = nil,
                batteryPercent: Double? = nil, firmware: String) {
        self.protocolType = protocolType; self.isOnline = isOnline; self.isOn = isOn
        self.powerWatts = powerWatts; self.batteryPercent = batteryPercent; self.firmware = firmware
    }
}

// MARK: - Time Series (historical data)

public struct TimeSeriesPoint: Codable, Hashable, Identifiable, Sendable {
    public var id: Date { timestamp }
    public var timestamp: Date
    public var value: Double
    public init(timestamp: Date, value: Double) { self.timestamp = timestamp; self.value = value }
}

public struct MetricHistory: Codable, Hashable, Sendable {
    public var metric: String
    public var unit: String
    public var points: [TimeSeriesPoint]
    public init(metric: String, unit: String, points: [TimeSeriesPoint]) {
        self.metric = metric; self.unit = unit; self.points = points
    }
}
