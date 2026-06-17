//
//  DroneModeView.swift
//  PRVIO EARTH
//
//  Drone & Satellite mode. Plan a flight, watch the OpenDroneMap
//  reconstruction pipeline progress, and apply the resulting aerial
//  products (orthomosaic, NDVI, LiDAR canopy, thermal) directly onto the
//  live twin map via the GIS engine. Bridges aerial reconstruction to the
//  spatial model.
//

import SwiftUI

@MainActor
@Observable
public final class DroneModeViewModel {
    public let vision: VisionEngine
    public let gis: GISEngine
    public let twin: DigitalTwinEngine

    public init(vision: VisionEngine, gis: GISEngine, twin: DigitalTwinEngine) {
        self.vision = vision
        self.gis = gis
        self.twin = twin
    }

    public var missions: [DroneMission] { vision.missions }

    /// Forest and orchard entities correlated to the active vegetation overlay.
    public var vegetationEntities: [PropertyEntity] {
        guard gis.overlay == .ndvi || gis.overlay == .canopyHeight else { return [] }
        return twin.entities
            .filter { $0.kind.module == .forest || $0.kind.module == .orchard }
            .sorted { $0.health.score > $1.health.score }
    }

    public var overlayLabel: String { gis.overlay.label }

    public func planFlight() {
        let mission = DroneMission(
            name: "Survey \(Date.now.formatted(.dateTime.month().day()))",
            stage: .planned,
            imageCount: Int.random(in: 240...780),
            areaHectares: Double.random(in: 1.5...6.0),
            products: [.orthomosaic, .ndvi, .canopyHeight])
        vision.addMission(mission)
        vision.runMission(mission.id)
    }

    /// Apply an aerial product as the active analytical overlay on the map.
    public func apply(_ product: AerialProduct) {
        withAnimation(.prvioMorph) {
            gis.overlay = product.overlay
            if product == .orthomosaic { gis.baseLayer = .satellite }
        }
    }
}

public struct DroneModeView: View {
    @State private var vm: DroneModeViewModel

    public init(vm: DroneModeViewModel) { self._vm = State(initialValue: vm) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                productGrid
                if !vm.vegetationEntities.isEmpty { healthCorrelationPanel }
                Text("Missions").font(.prvioHeadline())
                if vm.missions.isEmpty {
                    Label("No flights yet — plan a survey above.", systemImage: "paperplane")
                        .font(.prvioLabel()).foregroundStyle(.secondary).padding(Spacing.md)
                }
                ForEach(vm.missions) { MissionCard(mission: $0) }
            }
            .padding(Spacing.lg)
            .padding(.top, 40)
        }
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial).ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Drone & Satellite").font(.prvioTitle())
            Text("Reconstruct your property from the air and project the results onto your twin.")
                .font(.prvioLabel()).foregroundStyle(.secondary)
            HStack {
                GlassButton("Plan Flight", systemImage: "paperplane.fill", tint: .prvioHorizon) { vm.planFlight() }
                GlassButton("Import LiDAR", systemImage: "square.and.arrow.down", tint: .domainForest) {}
            }
        }
    }

    private var productGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Apply to map").font(.prvioHeadline())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                ForEach(AerialProduct.allCases) { product in
                    Button { vm.apply(product) } label: {
                        HStack {
                            Image(systemName: product.symbol).foregroundStyle(.domainForest)
                            Text(product.label).font(.prvioLabel()).lineLimit(1)
                            Spacer()
                            if vm.gis.overlay == product.overlay && product.overlay != .none {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.healthThriving)
                            }
                        }
                        .padding(Spacing.md)
                        .liquidGlass(.raised, tint: .domainForest, interactive: false)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var healthCorrelationPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("\(vm.overlayLabel) — Health Correlation", systemImage: "chart.bar.xaxis.ascending")
                .font(.prvioHeadline())
            ForEach(vm.vegetationEntities.prefix(6)) { entity in
                HStack(spacing: Spacing.md) {
                    Image(systemName: entity.kind.symbol)
                        .foregroundStyle(entity.health.score.healthColor).frame(width: 24)
                    Text(entity.name).font(.prvioLabel()).lineLimit(1)
                    Spacer()
                    ProgressView(value: entity.health.score)
                        .tint(entity.health.score.healthColor)
                        .frame(width: 72)
                    Text("\(Int(entity.health.score * 100))%")
                        .font(.prvioCaption()).foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
                .padding(Spacing.md)
                .liquidGlass(.raised, tint: .domainForest, interactive: false)
            }
        }
    }
}

private struct MissionCard: View {
    var mission: DroneMission
    private var isDone: Bool { mission.stage == .complete }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: isDone ? "checkmark.seal.fill" : "airplane")
                    .foregroundStyle(isDone ? .healthThriving : .prvioHorizon)
                Text(mission.name).font(.prvioLabel())
                Spacer()
                Text(mission.stage.label).font(.prvioCaption())
                    .foregroundStyle(isDone ? .healthThriving : .secondary)
            }
            if !isDone {
                ProgressView(value: mission.stage.progress).tint(.prvioHorizon)
            }
            HStack(spacing: Spacing.md) {
                Label("\(mission.imageCount) imgs", systemImage: "photo.stack")
                Label(String(format: "%.1f ha", mission.areaHectares), systemImage: "ruler")
                Label("\(mission.products.count) products", systemImage: "square.3.layers.3d")
            }
            .font(.prvioCaption()).foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: .prvioHorizon, interactive: false)
    }
}
