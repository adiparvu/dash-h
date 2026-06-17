//
//  TwinSnapshotBridge.swift
//  PRVIO EARTH
//
//  Lightweight twin snapshot written to the shared App Group so the
//  Widget Extension and App Intents extension can read fresh data without
//  spinning up the full Digital Twin Engine. Written on every insight
//  recompute; read by widgets at their 15-minute refresh cadence.
//

import Foundation

// MARK: - Snapshot model (written by app, read by widgets & intents)

public struct TwinSnapshot: Codable, Sendable {
    public var propertyHealth: Double  // 0...1
    public var alerts: Int
    public var topInsight: String
    public var energyKwh: Double
    public var capturedAt: Date
    /// Per-module health keyed by `PropertyModule.rawValue`. Written by the
    /// engine on every insight recompute; older snapshots decode with `[:]`.
    public var moduleHealth: [String: Double]

    public init(propertyHealth: Double, alerts: Int, topInsight: String,
                energyKwh: Double, capturedAt: Date = .now,
                moduleHealth: [String: Double] = [:]) {
        self.propertyHealth = propertyHealth
        self.alerts = alerts
        self.topInsight = topInsight
        self.energyKwh = energyKwh
        self.capturedAt = capturedAt
        self.moduleHealth = moduleHealth
    }

    // Backward-compatible decoder: snapshots persisted before moduleHealth
    // was added will decode with an empty dict rather than throwing.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        propertyHealth = try c.decode(Double.self, forKey: .propertyHealth)
        alerts         = try c.decode(Int.self, forKey: .alerts)
        topInsight     = try c.decode(String.self, forKey: .topInsight)
        energyKwh      = try c.decode(Double.self, forKey: .energyKwh)
        capturedAt     = (try? c.decode(Date.self, forKey: .capturedAt)) ?? .now
        moduleHealth   = (try? c.decode([String: Double].self, forKey: .moduleHealth)) ?? [:]
    }

    public static let placeholder = TwinSnapshot(
        propertyHealth: 0.86, alerts: 2,
        topInsight: "Orchard soil moisture low", energyKwh: 32.6,
        moduleHealth: [
            "forest": 0.90, "orchard": 0.75, "pond": 0.88,
            "garden": 0.82, "greenhouse": 0.91, "home": 0.95, "agriculture": 0.78,
        ])
}

// MARK: - Bridge (App Group UserDefaults)

public enum TwinSnapshotBridge {
    public static let appGroupSuite = "group.com.prvio.earth"
    private static let key = "twin.snapshot.v1"

    public static func save(_ snapshot: TwinSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot),
              let defaults = UserDefaults(suiteName: appGroupSuite) else { return }
        defaults.set(data, forKey: key)
    }

    public static func load() -> TwinSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupSuite),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TwinSnapshot.self, from: data)
    }
}
