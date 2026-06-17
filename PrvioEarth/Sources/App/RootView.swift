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
import CoreSpotlight

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
    @State private var showSettings = false

    public init() {
        let saved = PersistenceStore.shared.loadEntities()
        let twin = DigitalTwinEngine(
            anchor: PropertySeed.anchor,
            seed: saved ?? PropertySeed.makeEntities(),
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
        .sheet(isPresented: $showSettings) {
            SettingsView { showSettings = false }
                .presentationDetents([.large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
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
            }, onOpenSettings: {
                showSystems = false
                showSettings = true
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
            DroneModeView(vm: DroneModeViewModel(vision: vision, gis: gis, twin: twin))
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
            let storedInterval = UserDefaults.standard.double(forKey: "telemetryIntervalSec")
            let seconds = storedInterval > 0 ? storedInterval : 5.0
            twin.startLiveTelemetry(interval: .seconds(seconds))
            intelligenceVM.onHighlight = { ids in
                mapVM.applyHighlight(ids)
                withAnimation(.prvioMorph) { module = .map }
            }
            Task {
                await NotificationEngine.shared.requestAuthorization()
                PrvioShortcutsProvider.updateAppShortcutParameters()
            }
        }
        .onChange(of: twin.insights) { _, insights in
            NotificationEngine.shared.schedule(insights)
        }
        .onDisappear { twin.stopLiveTelemetry() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { PersistenceStore.shared.save(entities: twin.entities) }
        }
        .userActivity("com.prvio.earth.module") { activity in
            activity.title = module == .map ? "Digital Twin" : module.title
            activity.userInfo = ["module": module.rawValue]
            activity.isEligibleForHandoff = true
            activity.isEligibleForSearch = false
        }
        .onContinueUserActivity("com.prvio.earth.module") { activity in
            guard let raw = activity.userInfo?["module"] as? String,
                  let m = PropertyModule(rawValue: raw) else { return }
            withAnimation(.prvioMorph) { module = m }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let idStr = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let uuid = UUID(uuidString: idStr),
                  let entity = twin.entity(uuid) else { return }
            focusEntity(entity)
        }
        .onContinueUserActivity("com.prvio.earth.entity") { activity in
            guard let idStr = activity.userInfo?["entityID"] as? String,
                  let uuid = UUID(uuidString: idStr),
                  let entity = twin.entity(uuid) else { return }
            focusEntity(entity)
        }
        .preferredColorScheme(.dark)
    }

    @Environment(\.scenePhase) private var scenePhase

    /// Navigate to the module that owns `entity`, then open its detail sheet.
    /// A short sleep lets the module transition animate before the sheet opens.
    private func focusEntity(_ entity: PropertyEntity) {
        withAnimation(.prvioMorph) { module = entity.kind.module }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            mapVM.select(entity)
        }
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
        case .forest, .orchard, .pond, .home, .garden, .greenhouse, .agriculture:
            ModuleDashboardView(module: module, twin: twin) { entity in
                withAnimation(.prvioMorph) { module = .map }
                mapVM.select(entity)
            }
            .background(.clear)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
