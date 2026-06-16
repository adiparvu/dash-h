//
//  PropertySeed.swift
//  PRVIO EARTH
//
//  Generates a believable demo property — house, pond, orchard rows,
//  forest stand, greenhouse, solar array and devices — so the Digital
//  Twin is fully alive in previews, demos and tests without a backend.
//

import Foundation

public enum PropertySeed {

    /// Property anchor (a rural estate). All entities are scattered around it.
    public static let anchor = GeoPoint(latitude: 45.7489, longitude: 21.2087, altitude: 120)

    public static func makeEntities() -> [PropertyEntity] {
        var out: [PropertyEntity] = []
        out.append(contentsOf: structures())
        out.append(contentsOf: orchard())
        out.append(contentsOf: forest())
        out.append(pond())
        out.append(contentsOf: devices())
        return out
    }

    // MARK: - Structures

    private static func structures() -> [PropertyEntity] {
        [
            PropertyEntity(name: "Main House", kind: .house,
                location: offset(0, 0),
                health: HealthState(score: 0.97),
                metrics: ["energyKwh": 18.4, "temp": 21.5]),
            PropertyEntity(name: "Greenhouse", kind: .greenhouse,
                location: offset(40, -30),
                health: HealthState(score: 0.88),
                metrics: ["temp": 26.0, "humidity": 0.71, "soilMoisture": 0.62]),
            PropertyEntity(name: "Garden Bed", kind: .garden,
                location: offset(-30, -20),
                health: HealthState(score: 0.82),
                metrics: ["soilMoisture": 0.55, "temp": 22.0]),
            PropertyEntity(name: "Weather Station", kind: .weatherStation,
                location: offset(60, 40),
                health: HealthState(score: 1.0),
                metrics: ["windKph": 12, "temp": 19.0, "rainMm": 0]),
        ]
    }

    // MARK: - Orchard

    private static func orchard() -> [PropertyEntity] {
        let species = ["Apple", "Pear", "Cherry", "Plum"]
        return (0..<8).map { i in
            let sp = species[i % species.count]
            let stressed = i == 3
            return PropertyEntity(
                name: "\(sp) Tree \(i + 1)", kind: .fruitTree,
                location: offset(Double(80 + (i % 4) * 12), Double(-60 - (i / 4) * 12)),
                health: HealthState(score: stressed ? 0.48 : Double.random(in: 0.74...0.93),
                                    diseaseRisk: stressed ? 0.68 : Double.random(in: 0.05...0.3)),
                metrics: ["soilMoisture": stressed ? 0.28 : 0.5, "expectedYieldKg": Double.random(in: 30...70)],
                detail: .orchard(OrchardProfile(
                    species: sp, phenophase: .fruiting,
                    expectedYieldKg: Double.random(in: 30...70),
                    lastHarvestKg: Double.random(in: 25...60),
                    nextHarvest: .now.addingTimeInterval(45 * 86_400),
                    irrigationActive: !stressed,
                    nextFertilization: .now.addingTimeInterval(10 * 86_400),
                    nextPruning: .now.addingTimeInterval(20 * 86_400))))
        }
    }

    // MARK: - Forest

    private static func forest() -> [PropertyEntity] {
        let species = ["Oak", "Beech", "Pine", "Birch", "Maple"]
        return (0..<10).map { i in
            let sp = species[i % species.count]
            let pest = i == 6
            return PropertyEntity(
                name: "\(sp) #\(i + 1)", kind: .tree,
                location: offset(Double(-100 - (i % 5) * 14), Double(40 + (i / 5) * 16)),
                health: HealthState(score: pest ? 0.52 : Double.random(in: 0.7...0.96),
                                    diseaseRisk: pest ? 0.55 : Double.random(in: 0...0.25)),
                metrics: ["soilMoisture": Double.random(in: 0.4...0.7), "height_m": Double.random(in: 8...24)],
                detail: .tree(TreeProfile(
                    species: sp, ageYears: Int.random(in: 12...80),
                    heightMeters: Double.random(in: 8...24),
                    trunkDiameterCm: Double.random(in: 20...70),
                    growthRateCmPerYear: Double.random(in: 15...45),
                    carbonStorageKg: Double.random(in: 200...1500),
                    biomassKg: Double.random(in: 400...3000),
                    pestDetected: pest,
                    soilMoisture: Double.random(in: 0.4...0.7),
                    soilPH: Double.random(in: 5.5...7.0))))
        }
    }

    // MARK: - Pond

    private static func pond() -> PropertyEntity {
        PropertyEntity(
            name: "Koi Pond", kind: .pond,
            location: offset(-50, 60),
            health: HealthState(score: 0.79),
            metrics: ["temp": 18.5, "pH": 7.2, "oxygen": 7.8, "waterLevel": 0.92],
            detail: .pond(PondProfile(
                waterTempC: 18.5, pH: 7.2, dissolvedOxygenMgL: 7.8,
                ammoniaMgL: 0.18, nitrateMgL: 12.0, waterLevelPercent: 92,
                fishCount: 24, pumpsOnline: 2, uvSterilizerOn: true)))
    }

    // MARK: - Devices

    private static func devices() -> [PropertyEntity] {
        [
            PropertyEntity(name: "Front Gate Camera", kind: .camera,
                location: offset(10, 70), health: HealthState(score: 1.0),
                metrics: [:],
                detail: .device(DeviceProfile(protocolType: .wifi, isOnline: true, isOn: true, firmware: "4.2.1"))),
            PropertyEntity(name: "Solar Array", kind: .solarPanel,
                location: offset(70, 10), health: HealthState(score: 0.95),
                metrics: ["powerW": 4200, "energyKwh": 32.6],
                detail: .device(DeviceProfile(protocolType: .mqtt, isOnline: true, isOn: true, powerWatts: 4200, firmware: "2.0.0"))),
            PropertyEntity(name: "Pond Pump A", kind: .pump,
                location: offset(-46, 58), health: HealthState(score: 0.9),
                metrics: ["powerW": 120],
                detail: .device(DeviceProfile(protocolType: .zigbee, isOnline: true, isOn: true, powerWatts: 120, firmware: "1.3.0"))),
            PropertyEntity(name: "Irrigation Valve 1", kind: .irrigationValve,
                location: offset(82, -58), health: HealthState(score: 0.93),
                metrics: ["flowLpm": 14],
                detail: .device(DeviceProfile(protocolType: .thread, isOnline: false, isOn: false, firmware: "1.1.2"))),
            PropertyEntity(name: "Aerator", kind: .aerator,
                location: offset(-54, 62), health: HealthState(score: 0.86),
                metrics: ["powerW": 60],
                detail: .device(DeviceProfile(protocolType: .matter, isOnline: true, isOn: true, powerWatts: 60, firmware: "5.0.1"))),
        ]
    }

    // MARK: - Automations

    public static func makeAutomations() -> [Automation] {
        [
            Automation(name: "Dawn Orchard Irrigation", nodes: [
                .init(role: .trigger, title: "Daily at sunrise", config: "06:10"),
                .init(role: .condition, title: "Soil moisture < 35%", config: "orchard.*"),
                .init(role: .action, title: "Open drip valves 20 min", config: "valve.orchard")
            ], module: .orchard),
            Automation(name: "Oxygen Guardian", nodes: [
                .init(role: .trigger, title: "Pond O₂ < 5 mg/L", config: "pond.oxygen"),
                .init(role: .action, title: "Activate aerators", config: "aerator.all"),
                .init(role: .action, title: "Notify owner", config: "push")
            ], module: .pond),
            Automation(name: "Night Security Sweep", nodes: [
                .init(role: .trigger, title: "Motion after 22:00", config: "camera.*"),
                .init(role: .condition, title: "No family home", config: "presence"),
                .init(role: .action, title: "Record + floodlight + alert", config: "security")
            ], module: .home),
        ]
    }

    // MARK: - Geo helper

    /// Offset the anchor by metres (east, north) → coordinate.
    private static func offset(_ east: Double, _ north: Double) -> GeoPoint {
        let dLat = north / 111_320.0
        let dLon = east / (111_320.0 * cos(anchor.latitude * .pi / 180))
        return GeoPoint(latitude: anchor.latitude + dLat, longitude: anchor.longitude + dLon)
    }
}
