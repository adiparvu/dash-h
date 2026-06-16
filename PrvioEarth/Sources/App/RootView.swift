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
    @State private var vision: VisionEngine
    @State private var mapVM: PropertyMapViewModel
    @State private var intelligenceVM: IntelligenceViewModel

    @State private var module: PropertyModule = .map
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: OnboardingViewModel.key)
    @State private var showSystems = false
    @State private var showAutomation = false
    @State private var showCamera = false
    @State private var showDrone = false
    @State private var showEditor = false

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
        _vision = State(initialValue: VisionEngine())
        _mapVM = State(initialValue: mapVM)
        _intelligenceVM = State(initialValue: intel)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Base layer — always the living twin
            PropertyMapView(vm: mapVM, module: $module) {
                withAnimation(.prvioMorph) { showSystems = true }
            }
            .ignoresSafeArea()

            // Floating module / intelligence surfaces above the twin
            overlayContent

            // The only persistent chrome
            FloatingNavBar(selection: $module, collapsed: mapVM.isExploring)
                .padding(.bottom, Spacing.sm)
        }
        .sheet(isPresented: $showSystems) {
            SystemsHubView(twin: twin, onOpenAutomation: {
                showSystems = false
                showAutomation = true
            }, onOpenCamera: {
                showSystems = false
                showCamera = true
            }, onOpenDrone: {
                showSystems = false
                showDrone = true
            }, onOpenEditor: {
                showSystems = false
                showEditor = true
            }, onFocusModule: { m in
                showSystems = false
                withAnimation(.prvioMorph) { module = m }
            })
            .presentationDetents([.large])
            .presentationBackground(.clear)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAutomation) {
            AutomationStudioView(vm: AutomationStudioViewModel(twin: twin))
                .presentationDetents([.large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCamera) {
            CameraAIView(vm: CameraAIViewModel(twin: twin, vision: vision))
                .presentationDetents([.large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDrone) {
            DroneModeView(vm: DroneModeViewModel(vision: vision, gis: gis))
                .presentationDetents([.large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showEditor) {
            PropertyEditorView(vm: PropertyEditorViewModel(twin: twin)) { showEditor = false }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { _ in showOnboarding = false }
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
