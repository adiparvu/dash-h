//
//  PropertyEntity.swift
//  PRVIO EARTH
//
//  The unifying abstraction of the Digital Twin: every physical thing on
//  the property — a tree, a pond, a pump, a camera, a building — is a
//  `PropertyEntity`. The map renders entities, the detail sheet inspects
//  them, and PRVIO Intelligence reasons over them. One protocol, every
//  Smart module.
//

import Foundation
import CoreLocation

// MARK: - Geo

/// Lightweight, Codable coordinate so models stay free of MapKit.
public struct GeoPoint: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double

    public init(latitude: Double, longitude: Double, altitude: Double = 0) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }

    public var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Entity Kind

public enum EntityKind: String, Codable, CaseIterable, Sendable {
    case tree, fruitTree, pond, greenhouse, garden, building, house
    case camera, sensor, pump, filter, aerator, irrigationValve
    case solarPanel, weatherStation, gate, equipment, pathway, fence

    public var module: PropertyModule {
        switch self {
        case .tree: return .forest
        case .fruitTree: return .orchard
        case .pond, .pump, .filter, .aerator: return .pond
        case .house, .building, .camera, .gate: return .home
        default: return .map
        }
    }

    public var symbol: String {
        switch self {
        case .tree: return "tree.fill"
        case .fruitTree: return "apple.logo"
        case .pond: return "drop.fill"
        case .greenhouse: return "leaf.fill"
        case .garden: return "camera.macro"
        case .building: return "building.2.fill"
        case .house: return "house.fill"
        case .camera: return "video.fill"
        case .sensor: return "sensor.fill"
        case .pump: return "engine.combustion.fill"
        case .filter: return "line.3.horizontal.decrease.circle.fill"
        case .aerator: return "wind"
        case .irrigationValve: return "spigot.fill"
        case .solarPanel: return "sun.max.fill"
        case .weatherStation: return "cloud.sun.fill"
        case .gate: return "door.left.hand.closed"
        case .equipment: return "wrench.and.screwdriver.fill"
        case .pathway: return "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .fence: return "rectangle.split.3x1.fill"
        }
    }
}

// MARK: - Health

public struct HealthState: Codable, Hashable, Sendable {
    public var score: Double           // 0...1
    public var diseaseRisk: Double      // 0...1
    public var lastAssessed: Date
    public var note: String?

    public init(score: Double, diseaseRisk: Double = 0, lastAssessed: Date = .now, note: String? = nil) {
        self.score = score
        self.diseaseRisk = diseaseRisk
        self.lastAssessed = lastAssessed
        self.note = note
    }

    public enum Status: String { case thriving, stable, stressed, critical }
    public var status: Status {
        switch score {
        case 0.8...: return .thriving
        case 0.6..<0.8: return .stable
        case 0.35..<0.6: return .stressed
        default: return .critical
        }
    }
}

// MARK: - The Universal Entity

public struct PropertyEntity: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var kind: EntityKind
    public var location: GeoPoint
    public var health: HealthState
    /// Free-form, kind-specific telemetry (e.g. ["pH": 7.2, "height_m": 18]).
    public var metrics: [String: Double]
    /// Module-specific structured payload, if any.
    public var detail: EntityDetail?
    public var lastUpdated: Date

    public init(
        id: UUID = UUID(),
        name: String,
        kind: EntityKind,
        location: GeoPoint,
        health: HealthState,
        metrics: [String: Double] = [:],
        detail: EntityDetail? = nil,
        lastUpdated: Date = .now
    ) {
        self.id = id; self.name = name; self.kind = kind
        self.location = location; self.health = health
        self.metrics = metrics; self.detail = detail
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Structured Detail Payloads

/// Strongly-typed payloads carried by entities of specific kinds. Kept as a
/// single enum so the Digital Twin Engine can store a heterogeneous set of
/// entities in one collection while preserving rich, type-safe detail.
public enum EntityDetail: Codable, Hashable, Sendable {
    case tree(TreeProfile)
    case orchard(OrchardProfile)
    case pond(PondProfile)
    case device(DeviceProfile)
}
