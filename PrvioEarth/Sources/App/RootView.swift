//
//  RootView.swift
//  PRVIO EARTH
//
//  Orchestrates the whole experience. The live Digital Twin map is always
//  the base layer; modules and PRVIO Intelligence morph in as floating
//  Liquid Glass surfaces above it. The floating nav bar is the only
//  persistent chrome. Map-first, object-centric, menu-free.
//

import SwiftUI

public struct RootView: View {
    @State private var twin: DigitalTwinEngine
    @State private var gis: GISEngine
    @State private var mapVM: PropertyMapViewModel
    @State private var intelligenceVM: IntelligenceViewModel

    @State private var module: PropertyModule = .map

    public init() {
        let twin = DigitalTwinEngine(
            anchor: PropertySeed.anchor,
            seed: PropertySeed.makeEntities(),
            automations: PropertySeed.makeAutomations())
        let gis = GISEngine(anchor: PropertySeed.anchor)
        let mapVM = PropertyMapViewModel(twin: twin, gis: gis)
        let intel = IntelligenceViewModel(twin: twin)

        _twin = State(initialValue: twin)
        _gis = State(initialValue: gis)
        _mapVM = State(initialValue: mapVM)
        _intelligenceVM = State(initialValue: intel)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Base layer — always the living twin
            PropertyMapView(vm: mapVM, module: $module)
                .ignoresSafeArea()

            // Floating module / intelligence surfaces above the twin
            overlayContent

            // The only persistent chrome
            FloatingNavBar(selection: $module, collapsed: mapVM.isExploring)
                .padding(.bottom, Spacing.sm)
        }
        .onAppear {
            twin.startLiveTelemetry()
            intelligenceVM.onHighlight = { ids in
                mapVM.applyHighlight(ids)
                withAnimation(.prvioMorph) { module = .map }
            }
        }
        .onDisappear { twin.stopLiveTelemetry() }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var overlayContent: some View {
        switch module {
        case .map:
            EmptyView()
        case .intelligence:
            IntelligenceView(vm: intelligenceVM)
                .padding(.top, 80)
                .padding(.bottom, 96)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .forest, .orchard, .pond, .home:
            ModuleDashboardView(module: module, twin: twin) { entity in
                withAnimation(.prvioMorph) { module = .map }
                mapVM.select(entity)
            }
            .background(.clear)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
