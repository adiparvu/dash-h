//
//  Vision.swift
//  PRVIO EARTH
//
//  Models for the visual intelligence layer: Camera AI detections and the
//  drone / satellite mapping pipeline. In production these are produced by
//  Core ML / Vision models on-device (and the OpenDroneMap pipeline for
//  aerial reconstruction); here they share the exact same shape so the UI
//  is fully buildable.
//

import Foundation
import CoreGraphics

// MARK: - Camera AI

public enum DetectionClass: String, Codable, CaseIterable, Sendable {
    case person, animal, bird, fish, vehicle
    case pest, disease, fallenTree, intrusion

    public var label: String {
        switch self {
        case .person: return "Person"
        case .animal: return "Animal"
        case .bird: return "Bird"
        case .fish: return "Fish"
        case .vehicle: return "Vehicle"
        case .pest: return "Pest"
        case .disease: return "Disease"
        case .fallenTree: return "Fallen Tree"
        case .intrusion: return "Intrusion"
        }
    }

    public var symbol: String {
        switch self {
        case .person: return "figure.walk"
        case .animal: return "pawprint.fill"
        case .bird: return "bird.fill"
        case .fish: return "fish.fill"
        case .vehicle: return "car.fill"
        case .pest: return "ant.fill"
        case .disease: return "allergens"
        case .fallenTree: return "tree.fill"
        case .intrusion: return "exclamationmark.shield.fill"
        }
    }

    /// Whether a detection of this class should raise a security/health alert.
    public var isAlerting: Bool {
        switch self {
        case .intrusion, .pest, .disease, .fallenTree: return true
        default: return false
        }
    }
}

/// A single recognized object in a camera frame. `boundingBox` is in
/// normalized (0...1) Vision coordinates, origin bottom-left.
public struct CameraDetection: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var classification: DetectionClass
    public var confidence: Double          // 0...1
    public var boundingBox: CGRect
    public var note: String?

    public init(classification: DetectionClass, confidence: Double, boundingBox: CGRect, note: String? = nil) {
        self.classification = classification
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.note = note
    }
}

public struct CameraFrame: Identifiable, Sendable {
    public let id = UUID()
    public var cameraEntityID: UUID
    public var capturedAt: Date
    public var detections: [CameraDetection]

    public init(cameraEntityID: UUID, capturedAt: Date = .now, detections: [CameraDetection]) {
        self.cameraEntityID = cameraEntityID
        self.capturedAt = capturedAt
        self.detections = detections
    }
}

// MARK: - Drone / Satellite Mapping

public enum AerialProduct: String, Codable, CaseIterable, Identifiable, Sendable {
    case orthomosaic, ndvi, canopyHeight, terrain, thermal
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .orthomosaic: return "Orthomosaic"
        case .ndvi: return "NDVI (Vegetation)"
        case .canopyHeight: return "Canopy Height (LiDAR)"
        case .terrain: return "Terrain (DEM)"
        case .thermal: return "Thermal"
        }
    }
    public var symbol: String {
        switch self {
        case .orthomosaic: return "map.fill"
        case .ndvi: return "leaf.fill"
        case .canopyHeight: return "mountain.2.fill"
        case .terrain: return "globe.desk.fill"
        case .thermal: return "thermometer.sun.fill"
        }
    }
    /// Maps to the live GIS overlay shown when this product is selected.
    public var overlay: GISEngine.DataOverlay {
        switch self {
        case .orthomosaic: return .orthomosaic
        case .ndvi: return .ndvi
        case .canopyHeight: return .canopyHeight
        case .thermal: return .thermal
        case .terrain: return .none
        }
    }
}

/// A drone flight that reconstructs aerial products via the OpenDroneMap
/// pipeline. Progresses through capture → upload → reconstruct → analyze.
public struct DroneMission: Identifiable, Hashable, Sendable {
    public enum Stage: String, Codable, CaseIterable, Sendable {
        case planned, flying, uploading, reconstructing, analyzing, complete
        public var label: String {
            switch self {
            case .planned: return "Planned"
            case .flying: return "Flying"
            case .uploading: return "Uploading imagery"
            case .reconstructing: return "Reconstructing 3D"
            case .analyzing: return "Analyzing"
            case .complete: return "Complete"
            }
        }
        public var progress: Double {
            guard let idx = Self.allCases.firstIndex(of: self) else { return 0 }
            return Double(idx) / Double(Self.allCases.count - 1)
        }
    }

    public let id: UUID
    public var name: String
    public var stage: Stage
    public var imageCount: Int
    public var areaHectares: Double
    public var products: [AerialProduct]
    public var flownAt: Date

    public init(id: UUID = UUID(), name: String, stage: Stage, imageCount: Int,
                areaHectares: Double, products: [AerialProduct], flownAt: Date = .now) {
        self.id = id; self.name = name; self.stage = stage
        self.imageCount = imageCount; self.areaHectares = areaHectares
        self.products = products; self.flownAt = flownAt
    }
}
