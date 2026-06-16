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
