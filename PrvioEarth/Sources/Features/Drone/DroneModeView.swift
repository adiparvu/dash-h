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

    public init(vision: VisionEngine, gis: GISEngine) {
        self.vision = vision
        self.gis = gis
    }

    public var missions: [DroneMission] { vision.missions }

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
