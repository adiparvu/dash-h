//
//  GISEngine.swift
//  PRVIO EARTH
//
//  Spatial backbone of the Digital Twin. Bridges PRVIO entities to MapKit
//  for the 2D/3D property map and exposes layer toggles (satellite,
//  NDVI, LiDAR canopy, drone orthomosaic) inspired by Leafmap, CesiumJS,
//  MapLibre and OpenDroneMap. Map rendering stays in MapKit; this engine
//  owns the data-to-space translation and overlay state.
//

import Foundation
import MapKit
import SwiftUI

@MainActor
@Observable
public final class GISEngine {

    public enum BaseLayer: String, CaseIterable, Sendable {
        case standard, satellite, terrain
        var mapStyle: MapStyle {
            switch self {
            case .standard: return .standard(elevation: .realistic)
            case .satellite: return .imagery(elevation: .realistic)
            case .terrain: return .hybrid(elevation: .realistic)
            }
        }
    }

    /// Analytical overlays sourced from drone & satellite pipelines.
    public enum DataOverlay: String, CaseIterable, Identifiable, Sendable {
        case none, ndvi, canopyHeight, soilMoisture, thermal, orthomosaic
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .none: return "None"
            case .ndvi: return "NDVI"
            case .canopyHeight: return "Canopy (LiDAR)"
            case .soilMoisture: return "Soil Moisture"
            case .thermal: return "Thermal"
            case .orthomosaic: return "Drone Map"
            }
        }
        public var icon: String {
            switch self {
            case .none: return "circle.slash"
            case .ndvi: return "leaf.fill"
            case .canopyHeight: return "mountain.2.fill"
            case .soilMoisture: return "humidity.fill"
            case .thermal: return "thermometer.sun.fill"
            case .orthomosaic: return "map.fill"
            }
        }
    }

    public var baseLayer: BaseLayer = .satellite
    public var overlay: DataOverlay = .none
    public var is3D: Bool = true
    public var cameraPosition: MapCameraPosition

    public init(anchor: GeoPoint) {
        let region = MKCoordinateRegion(
            center: anchor.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004))
        self.cameraPosition = .region(region)
    }

    public func focus(on entity: PropertyEntity, distance: CLLocationDistance = 180) {
        let camera = MapCamera(
            centerCoordinate: entity.location.coordinate,
            distance: distance,
            heading: 30,
            pitch: is3D ? 60 : 0)
        cameraPosition = .camera(camera)
    }

    public func toggleDimension() {
        is3D.toggle()
    }

    /// NDVI-style health color used to tint overlay markers when an
    /// analytical layer is active.
    public func overlayColor(for entity: PropertyEntity) -> Color? {
        switch overlay {
        case .none: return nil
        case .ndvi, .canopyHeight: return entity.health.score.healthColor
        case .soilMoisture:
            let m = entity.metrics["soilMoisture"] ?? 0.5
            return Color(hue: 0.58, saturation: 0.8, brightness: 0.5 + m * 0.5)
        case .thermal:
            let t = entity.metrics["temp"] ?? 20
            return Color(hue: max(0, 0.7 - t / 60), saturation: 0.9, brightness: 0.9)
        case .orthomosaic: return .clear
        }
    }
}

// MARK: - Zone Polygon Helpers

extension GISEngine {

    /// Lightweight data holder for a module's zone boundary polygon.
    public struct ZonePolygonData: Identifiable, Sendable {
        public let id: PropertyModule
        public let coordinates: [CLLocationCoordinate2D]
        public let tint: Color
    }

    /// Andrew's monotone chain convex hull.  Returns the input unchanged when
    /// fewer than 3 points are supplied (polygons need at least 3 vertices).
    public static func convexHull(_ points: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard points.count >= 3 else { return points }
        let sorted = points.sorted {
            $0.latitude != $1.latitude ? $0.latitude < $1.latitude : $0.longitude < $1.longitude
        }
        func cross(_ o: CLLocationCoordinate2D,
                   _ a: CLLocationCoordinate2D,
                   _ b: CLLocationCoordinate2D) -> Double {
            (a.latitude  - o.latitude)  * (b.longitude - o.longitude) -
            (a.longitude - o.longitude) * (b.latitude  - o.latitude)
        }
        var lower: [CLLocationCoordinate2D] = []
        for p in sorted {
            while lower.count >= 2 && cross(lower[lower.count-2], lower[lower.count-1], p) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }
        var upper: [CLLocationCoordinate2D] = []
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count-2], upper[upper.count-1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }
        upper.removeLast(); lower.removeLast()
        return lower + upper
    }

    /// Convex hull expanded outward from its centroid by `paddingMeters`.
    public static func expandedHull(
        _ points: [CLLocationCoordinate2D],
        paddingMeters: Double = 20
    ) -> [CLLocationCoordinate2D] {
        let hull = convexHull(points)
        guard !hull.isEmpty else { return hull }
        let centLat = hull.map(\.latitude).reduce(0, +)  / Double(hull.count)
        let centLon = hull.map(\.longitude).reduce(0, +) / Double(hull.count)
        let dLat = paddingMeters / 111_000.0
        let cosLat = cos(centLat * .pi / 180)
        let dLon = cosLat > 1e-6 ? paddingMeters / (111_000.0 * cosLat) : dLat
        return hull.map { coord in
            let latDiff = coord.latitude  - centLat
            let lonDiff = coord.longitude - centLon
            let dist = (latDiff * latDiff + lonDiff * lonDiff).squareRoot()
            guard dist > 0 else { return coord }
            let scale = 1.0 + max(dLat, dLon) / dist
            return CLLocationCoordinate2D(
                latitude:  centLat + latDiff * scale,
                longitude: centLon + lonDiff * scale)
        }
    }
}
