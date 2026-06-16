//
//  PropertyMapViewModel.swift
//  PRVIO EARTH
//
//  Drives the primary interface — the live Digital Twin map. Owns
//  selection, map-interaction state and the bridge between the GIS engine
//  and the twin. Views stay declarative; all map orchestration lives here.
//

import SwiftUI

@MainActor
@Observable
public final class PropertyMapViewModel {

    public let twin: DigitalTwinEngine
    public let gis: GISEngine
    private let ai = AIEngine()

    /// Currently inspected entity (drives the Liquid Glass detail sheet).
    public var selectedEntity: PropertyEntity?

    /// Entities highlighted by PRVIO Intelligence (e.g. "show stressed trees").
    public var highlightedIDs: Set<UUID> = []

    /// True while the user is panning/zooming — collapses chrome out of the way.
    public var isExploring = false

    /// Module filter applied to which entities render.
    public var activeModule: PropertyModule = .map

    public init(twin: DigitalTwinEngine, gis: GISEngine) {
        self.twin = twin
        self.gis = gis
    }

    public var visibleEntities: [PropertyEntity] {
        twin.entities(in: activeModule)
    }

    public func select(_ entity: PropertyEntity) {
        withAnimation(.prvioMorph) {
            selectedEntity = entity
            gis.focus(on: entity)
        }
    }

    public func dismissSelection() {
        withAnimation(.prvioMorph) { selectedEntity = nil }
    }

    public func isHighlighted(_ entity: PropertyEntity) -> Bool {
        highlightedIDs.isEmpty ? false : highlightedIDs.contains(entity.id)
    }

    /// Dim an entity when a highlight set is active and it's not in it.
    public func isDimmed(_ entity: PropertyEntity) -> Bool {
        !highlightedIDs.isEmpty && !highlightedIDs.contains(entity.id)
    }

    public func applyHighlight(_ ids: [UUID]) {
        withAnimation(.prvioMorph) { highlightedIDs = Set(ids) }
    }

    public func clearHighlight() {
        withAnimation(.prvioMorph) { highlightedIDs.removeAll() }
    }

    public func live(_ entity: PropertyEntity) -> PropertyEntity {
        twin.entity(entity.id) ?? entity
    }
}
