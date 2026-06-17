//
//  ImmersiveTwinView.swift
//  PRVIO EARTH — visionOS
//
//  Vision Pro readiness. The same DigitalTwinEngine drives a volumetric
//  RealityKit scene: the property rendered as a tabletop model, with
//  entities as tappable 3D anchors that open the shared Liquid Glass
//  detail panels. On-site, the same anchors drive AR overlays for tree
//  inspection, pond monitoring and navigation.
//
//  NOTE: Compiles under visionOS. Guarded so the package builds on iOS too.
//

#if os(visionOS)
import SwiftUI
import RealityKit
import PrvioEarthCore

public struct ImmersiveTwinView: View {
    var twin: DigitalTwinEngine
    @State private var selection: PropertyEntity?
    @State private var sceneRoot: Entity?

    public init(twin: DigitalTwinEngine) { self.twin = twin }

    public var body: some View {
        RealityView { content, attachments in
            let root = Entity()
            content.add(root)
            sceneRoot = root

            for entity in twin.entities {
                let marker = ModelEntity(
                    mesh: .generateSphere(radius: 0.02),
                    materials: [SimpleMaterial(color: .init(entity.health.score.uiColor), isMetallic: false)])
                marker.position = position(for: entity)
                marker.components.set(InputTargetComponent())
                marker.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.03)]))
                marker.name = entity.id.uuidString
                root.addChild(marker)
            }
        } update: { _, _ in
            guard let root = sceneRoot else { return }
            for entity in twin.entities {
                guard let marker = root.findEntity(named: entity.id.uuidString) as? ModelEntity else { continue }
                marker.model?.materials = [SimpleMaterial(color: .init(entity.health.score.uiColor), isMetallic: false)]
            }
        } attachments: {
            if let selection {
                Attachment(id: "detail") {
                    ObjectDetailSheet(entity: selection, twin: twin)
                        .frame(width: 400, height: 520)
                        .glassBackgroundEffect()
                }
            }
        }
        .gesture(
            SpatialTapGesture().targetedToAnyEntity().onEnded { value in
                if let id = UUID(uuidString: value.entity.name) {
                    selection = twin.entity(id)
                }
            })
    }

    /// Lay entities out on a 1m tabletop relative to the property anchor.
    private func position(for entity: PropertyEntity) -> SIMD3<Float> {
        let dLat = entity.location.latitude - twin.anchor.latitude
        let dLon = entity.location.longitude - twin.anchor.longitude
        let scale: Float = 4000
        return [Float(dLon) * scale, 0, Float(-dLat) * scale]
    }
}

private extension Double {
    var uiColor: UIColor {
        switch self {
        case 0.8...: return UIColor(red: 0.24, green: 0.80, blue: 0.44, alpha: 1)
        case 0.6..<0.8: return UIColor(red: 0.62, green: 0.80, blue: 0.30, alpha: 1)
        case 0.35..<0.6: return UIColor(red: 0.95, green: 0.72, blue: 0.20, alpha: 1)
        default: return UIColor(red: 0.92, green: 0.30, blue: 0.32, alpha: 1)
        }
    }
}
#endif
