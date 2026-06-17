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

    public init(propertyHealth: Double, alerts: Int, topInsight: String,
                energyKwh: Double, capturedAt: Date = .now) {
        self.propertyHealth = propertyHealth
        self.alerts = alerts
        self.topInsight = topInsight
        self.energyKwh = energyKwh
        self.capturedAt = capturedAt
    }

    public static let placeholder = TwinSnapshot(
        propertyHealth: 0.86, alerts: 2,
        topInsight: "Orchard soil moisture low", energyKwh: 32.6)
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
