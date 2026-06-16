//
//  PropertyMapView.swift
//  PRVIO EARTH
//
//  THE primary interface. A live 2D/3D Digital Twin filling the screen,
//  with floating Liquid Glass chrome layered above. Everything is
//  object-centric: the user manages the property by tapping entities, not
//  navigating menus. This is the first thing seen on launch.
//

import SwiftUI
import MapKit

public struct PropertyMapView: View {
    @State private var vm: PropertyMapViewModel
    @Binding var module: PropertyModule

    public init(vm: PropertyMapViewModel, module: Binding<PropertyModule>) {
        self._vm = State(initialValue: vm)
        self._module = module
    }

    public var body: some View {
        ZStack {
            mapLayer
                .ignoresSafeArea()

            // Floating chrome above the twin
            VStack {
                topBar
                Spacer()
                if !vm.isExploring { layerDock.transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .padding(Spacing.md)
            .allowsHitTesting(vm.selectedEntity == nil)
        }
        .onChange(of: module) { _, new in
            withAnimation(.prvioMorph) { vm.activeModule = new }
        }
        .sheet(item: Binding(get: { vm.selectedEntity }, set: { if $0 == nil { vm.dismissSelection() } })) { entity in
            ObjectDetailSheet(entity: vm.live(entity), twin: vm.twin)
                .presentationDetents([.fraction(0.45), .large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: Binding(get: { vm.gis.cameraPosition }, set: { vm.gis.cameraPosition = $0 })) {
            ForEach(vm.visibleEntities) { entity in
                Annotation(entity.name, coordinate: entity.location.coordinate) {
                    EntityMarker(
                        entity: vm.live(entity),
                        isSelected: vm.selectedEntity?.id == entity.id,
                        isHighlighted: vm.isHighlighted(entity),
                        isDimmed: vm.isDimmed(entity),
                        overlayTint: vm.gis.overlayColor(for: entity)
                    ) { vm.select(entity) }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(vm.gis.baseLayer.mapStyle)
        .mapControlVisibility(.hidden)
        .onMapCameraChange(frequency: .continuous) { _ in
            if !vm.isExploring { withAnimation(.prvioSnappy) { vm.isExploring = true } }
        }
        .onMapCameraChange(frequency: .onEnd) { _ in
            withAnimation(.prvioMorph.delay(1.2)) { vm.isExploring = false }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PRVIO EARTH")
                    .font(.prvioCaption()).foregroundStyle(.secondary)
                Text(module == .map ? "Digital Twin" : module.title)
                    .font(.prvioHeadline())
            }
            .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
            .liquidGlass(.floating, tint: module.tint)

            Spacer()

            if !vm.highlightedIDs.isEmpty {
                GlassButton("Clear", systemImage: "xmark", tint: .domainSecurity) { vm.clearHighlight() }
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Layer Dock (2D/3D + analytical overlays)

    private var layerDock: some View {
        HStack(spacing: Spacing.sm) {
            Button { withAnimation(.prvioMorph) { vm.gis.toggleDimension() } } label: {
                Label(vm.gis.is3D ? "3D" : "2D", systemImage: vm.gis.is3D ? "view.3d" : "square.2.layers.3d")
                    .font(.prvioLabel())
                    .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                    .liquidGlass(.floating, tint: .prvioHorizon, interactive: false)
            }.buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(GISEngine.DataOverlay.allCases) { layer in
                        Button { withAnimation(.prvioMorph) { vm.gis.overlay = layer } } label: {
                            Label(layer.label, systemImage: layer.icon)
                                .font(.prvioCaption())
                                .padding(.horizontal, Spacing.sm + 2).padding(.vertical, Spacing.sm)
                                .foregroundStyle(vm.gis.overlay == layer ? .white : .primary)
                                .background {
                                    if vm.gis.overlay == layer {
                                        Capsule().fill(Color.domainForest.gradient)
                                    }
                                }
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(6)
            .liquidGlass(.floating, tint: .prvioMist, interactive: false)
        }
    }
}
