//
//  PropertyAnalytics.swift
//  PRVIO EARTH
//
//  Derived, cross-cutting analytics computed from the live twin. The
//  Energy, Weather, Water and Security surfaces are *views* over the same
//  entities — never separate data stores — so everything stays consistent
//  with the map. Pure functions over `[PropertyEntity]`, easy to test.
//

import Foundation

public enum PropertyAnalytics {

    // MARK: - Energy

    public struct EnergySummary: Sendable {
        public var generationWatts: Double      // solar etc.
        public var consumptionWatts: Double     // devices drawing power
        public var todayKwh: Double
        public var net: Double { generationWatts - consumptionWatts }
        public var isExporting: Bool { net > 0 }
    }

    public static func energy(_ entities: [PropertyEntity]) -> EnergySummary {
        var gen = 0.0, con = 0.0, kwh = 0.0
        for e in entities {
            let p = e.metrics["powerW"] ?? 0
            if e.kind == .solarPanel { gen += p } else { con += p }
            kwh += e.metrics["energyKwh"] ?? 0
        }
        return EnergySummary(generationWatts: gen, consumptionWatts: con, todayKwh: kwh)
    }

    // MARK: - Weather

    public struct WeatherSummary: Sendable {
        public var tempC: Double
        public var windKph: Double
        public var rainMm: Double
        public var condition: String
        public var symbol: String
    }

    public static func weather(_ entities: [PropertyEntity]) -> WeatherSummary {
        let station = entities.first { $0.kind == .weatherStation }
        let temp = station?.metrics["temp"] ?? 19
        let wind = station?.metrics["windKph"] ?? 8
        let rain = station?.metrics["rainMm"] ?? 0
        let (condition, symbol): (String, String) = {
            if rain > 1 { return ("Rain", "cloud.rain.fill") }
            if wind > 25 { return ("Windy", "wind") }
            if temp > 28 { return ("Hot & Clear", "sun.max.fill") }
            return ("Clear", "sun.max.fill")
        }()
        return WeatherSummary(tempC: temp, windKph: wind, rainMm: rain, condition: condition, symbol: symbol)
    }

    // MARK: - Security

    public struct SecuritySummary: Sendable {
        public var cameras: Int
        public var camerasOnline: Int
        public var gatesSecured: Int
        public var armed: Bool
        public var allClear: Bool { camerasOnline == cameras }
    }

    public static func security(_ entities: [PropertyEntity]) -> SecuritySummary {
        let cams = entities.filter { $0.kind == .camera }
        let online = cams.filter { if case .device(let d) = $0.detail { return d.isOnline } ; return false }
        let gates = entities.filter { $0.kind == .gate }
        return SecuritySummary(
            cameras: cams.count,
            camerasOnline: online.count,
            gatesSecured: gates.count,
            armed: true)
    }

    // MARK: - Water

    public struct WaterSummary: Sendable {
        public var pondLevelPercent: Double
        public var irrigationValvesOpen: Int
        public var pumpsOnline: Int
    }

    public static func water(_ entities: [PropertyEntity]) -> WaterSummary {
        let pond = entities.first { if case .pond = $0.detail { return true }; return false }
        var level = 100.0
        if case .pond(let p)? = pond?.detail { level = p.waterLevelPercent }
        let valves = entities.filter { $0.kind == .irrigationValve && ($0.metrics["flowLpm"] ?? 0) > 0 }
        let pumps = entities.filter { e in
            guard e.kind == .pump else { return false }
            if case .device(let d) = e.detail { return d.isOnline }
            return false
        }
        return WaterSummary(pondLevelPercent: level, irrigationValvesOpen: valves.count, pumpsOnline: pumps.count)
    }
}
