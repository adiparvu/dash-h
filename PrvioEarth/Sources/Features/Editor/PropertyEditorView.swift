//
//  PropertyEditorView.swift
//  PRVIO EARTH
//
//  The hands-on way to build your Digital Twin: tap anywhere on the map to
//  drop an entity, pick what it is, name it, and it becomes a live, tappable
//  part of the twin immediately. Long-press an existing entity to remove it.
//  Same map, same Liquid Glass language as the main experience — building
//  the property is itself a spatial interaction.
//

import SwiftUI
import MapKit

@MainActor
@Observable
public final class PropertyEditorViewModel {
    public let twin: DigitalTwinEngine
    public var cameraPosition: MapCameraPosition

    /// A tapped-but-not-yet-placed location awaiting kind + name.
    public var pendingCoordinate: CLLocationCoordinate2D?
    public var draftKind: EntityKind = .tree
    public var draftName: String = ""
    /// ID of the last successfully placed entity — used by the undo button.
    public var lastAddedID: UUID? = nil

    public init(twin: DigitalTwinEngine) {
        self.twin = twin
        self.cameraPosition = .region(MKCoordinateRegion(
            center: twin.anchor.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)))
    }

    public var entities: [PropertyEntity] { twin.entities }

    public func beginPlacement(at coordinate: CLLocationCoordinate2D) {
        draftName = ""
        draftKind = .tree
        withAnimation(.prvioMorph) { pendingCoordinate = coordinate }
    }

    public func cancelPlacement() {
        withAnimation(.prvioMorph) { pendingCoordinate = nil }
    }

    public func confirmPlacement() {
        guard let coord = pendingCoordinate else { return }
        let name = draftName.isEmpty ? defaultName(for: draftKind) : draftName
        let entity = PropertyEntity(
            name: name,
            kind: draftKind,
            location: GeoPoint(latitude: coord.latitude, longitude: coord.longitude),
            health: HealthState(score: 0.9),
            metrics: [:],
            detail: defaultDetail(for: draftKind))
        twin.addEntity(entity)
        lastAddedID = entity.id
        withAnimation(.prvioMorph) { pendingCoordinate = nil }
    }

    public func undoLastPlacement() {
        guard let id = lastAddedID else { return }
        withAnimation(.prvioMorph) { twin.removeEntity(id) }
        lastAddedID = nil
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func defaultDetail(for kind: EntityKind) -> EntityDetail? {
        let week: TimeInterval = 7 * 86_400
        switch kind {
        case .tree:
            return .tree(TreeProfile(species: "Unknown", ageYears: 5, heightMeters: 6,
                                     trunkDiameterCm: 18, growthRateCmPerYear: 30,
                                     carbonStorageKg: 40, biomassKg: 120, soilMoisture: 0.5, soilPH: 6.5))
        case .fruitTree, .beehive:
            return .orchard(OrchardProfile(species: "Unknown", phenophase: .budding,
                                           expectedYieldKg: 30, lastHarvestKg: 28,
                                           nextHarvest: .now.addingTimeInterval(120 * 86_400),
                                           irrigationActive: false,
                                           nextFertilization: .now.addingTimeInterval(week),
                                           nextPruning: .now.addingTimeInterval(4 * week)))
        case .pond, .pump, .filter, .aerator:
            return .pond(PondProfile(waterTempC: 18, pH: 7.2, dissolvedOxygenMgL: 8.5,
                                     ammoniaMgL: 0.1, nitrateMgL: 10, waterLevelPercent: 85,
                                     fishCount: 20, pumpsOnline: 1, uvSterilizerOn: true))
        case .garden, .soilSensor:
            return .garden(GardenProfile(
                beds: ["Bed A", "Bed B"],
                soilMoisture: 0.55, soilPH: 6.8, soilTemperatureC: 20,
                lastWatered: .now, nextWatering: .now.addingTimeInterval(2 * 86_400),
                sunHoursPerDay: 7, mulched: false, companions: []))
        case .greenhouse, .growLight, .crop:
            return .greenhouse(GreenhouseProfile(
                temperatureC: 22, humidity: 0.65, co2Ppm: 800, lightLux: 20_000,
                growLightsOn: false, ventilationOn: true, zones: 2,
                crops: ["Tomato", "Basil"]))
        case .cropZone, .irrigationPivot:
            return .agriculture(AgricultureProfile(
                cropType: "Unknown", fieldAreaHa: 1.0, soilType: "Loam",
                growthStage: .seedling,
                npk: AgricultureProfile.NPKProfile(nitrogen: 80, phosphorus: 40, potassium: 60),
                soilMoisture: 0.5,
                plantingDate: .now,
                expectedHarvest: .now.addingTimeInterval(90 * 86_400),
                irrigationEfficiency: 0.75, yieldForecastTha: 3.0))
        case .camera, .sensor, .solarPanel, .weatherStation, .house, .building,
             .gate, .irrigationValve, .equipment, .pathway, .fence:
            return .device(DeviceProfile(protocolType: .wifi, isOnline: true, isOn: true, firmware: "1.0.0"))
        }
    }

    public func remove(_ entity: PropertyEntity) {
        withAnimation(.prvioMorph) { twin.removeEntity(entity.id) }
    }

    private func defaultName(for kind: EntityKind) -> String {
        let count = twin.entities.filter { $0.kind == kind }.count + 1
        return "\(kind.rawValue.capitalized) \(count)"
    }

    /// Kinds offered in the palette, grouped by the module they belong to.
    public let palette: [EntityKind] = [
        .tree, .fruitTree, .pond, .greenhouse, .garden,
        .house, .building, .camera, .sensor, .pump,
        .irrigationValve, .solarPanel, .weatherStation, .gate,
        .cropZone, .irrigationPivot,
    ]
}

public struct PropertyEditorView: View {
    @State private var vm: PropertyEditorViewModel
    var onDone: () -> Void

    public init(vm: PropertyEditorViewModel, onDone: @escaping () -> Void) {
        self._vm = State(initialValue: vm)
        self.onDone = onDone
    }

    public var body: some View {
        ZStack {
            mapLayer.ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                if vm.pendingCoordinate != nil { placementPanel }
                else { hint }
            }
            .padding(Spacing.md)
        }
        .preferredColorScheme(.dark)
    }

    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $vm.cameraPosition) {
                ForEach(vm.entities) { entity in
                    Annotation(entity.name, coordinate: entity.location.coordinate) {
                        EntityMarker(entity: entity, isSelected: false, isHighlighted: false,
                                     isDimmed: vm.pendingCoordinate != nil, overlayTint: nil) {
                            vm.remove(entity)
                        }
                        .accessibilityHint("Double tap to remove")
                    }
                    .annotationTitles(.hidden)
                }
                if let coord = vm.pendingCoordinate {
                    Annotation("New", coordinate: coord) {
                        PlacementPin(kind: vm.draftKind)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .onTapGesture { location in
                if let coord = proxy.convert(location, from: .local) {
                    vm.beginPlacement(at: coord)
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Build your Twin").font(.prvioHeadline())
                Text("\(vm.entities.count) entities").font(.prvioCaption()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
            .liquidGlass(.floating, tint: .prvioHorizon)
            Spacer()
            if vm.lastAddedID != nil {
                GlassButton("Undo", systemImage: "arrow.uturn.backward", tint: .domainSecurity) {
                    vm.undoLastPlacement()
                }
            }
            GlassButton("Done", systemImage: "checkmark", tint: .healthThriving, action: onDone)
        }
    }

    private var hint: some View {
        Label("Tap the map to place an entity · tap an entity to remove it",
              systemImage: "hand.tap.fill")
            .font(.prvioCaption())
            .padding(Spacing.md)
            .liquidGlass(.floating, tint: .prvioMist, interactive: false)
    }

    private var placementPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("What did you place?").font(.prvioHeadline())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(vm.palette, id: \.self) { kind in
                        Button { withAnimation(.prvioSnappy) { vm.draftKind = kind } } label: {
                            VStack(spacing: 6) {
                                Image(systemName: kind.symbol)
                                Text(kind.rawValue.capitalized).font(.system(size: 10)).lineLimit(1)
                            }
                            .foregroundStyle(vm.draftKind == kind ? .white : .primary)
                            .frame(width: 72, height: 60)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(vm.draftKind == kind ? AnyShapeStyle(kind.module.tint.gradient) : AnyShapeStyle(.ultraThinMaterial))
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Image(systemName: vm.draftKind.symbol).foregroundStyle(vm.draftKind.module.tint)
                TextField(vm.draftKind.rawValue.capitalized, text: $vm.draftName).font(.prvioLabel())
            }
            .padding(Spacing.md)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))

            HStack {
                GlassButton("Add", systemImage: "plus", tint: .healthThriving) { vm.confirmPlacement() }
                GlassButton("Cancel", systemImage: "xmark", tint: .domainSecurity) { vm.cancelPlacement() }
            }
        }
        .padding(Spacing.md)
        .liquidGlass(.modal, tint: vm.draftKind.module.tint)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct PlacementPin: View {
    var kind: EntityKind
    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .padding(10)
            .background(Circle().fill(kind.module.tint.gradient))
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(radius: 6)
    }
}
