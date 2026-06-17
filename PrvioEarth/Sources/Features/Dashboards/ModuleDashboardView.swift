//
//  ModuleDashboardView.swift
//  PRVIO EARTH
//
//  A spatial, object-centric module overview. NOT an enterprise dashboard:
//  it's a Liquid Glass summary that floats over a filtered twin, leading
//  with an aggregate health ring and letting the user dive straight back
//  to entities on the map. Reused for every module — swaps to a
//  module-specific detail sheet for Pond, Garden and Greenhouse.
//

import SwiftUI

public struct ModuleDashboardView: View {
    var module: PropertyModule
    var twin: DigitalTwinEngine
    var onSelectEntity: (PropertyEntity) -> Void

    public init(module: PropertyModule, twin: DigitalTwinEngine, onSelectEntity: @escaping (PropertyEntity) -> Void) {
        self.module = module; self.twin = twin; self.onSelectEntity = onSelectEntity
    }

    private var entities: [PropertyEntity] { twin.entities(in: module) }
    private var insights: [PrvioInsight] { twin.insights(for: module) }

    @State private var showModuleDetail = false

    private var hasModuleDetail: Bool {
        [.forest, .orchard, .pond, .garden, .greenhouse, .agriculture, .home].contains(module)
    }

    private var moduleDetailLabel: String {
        switch module {
        case .forest: return "Carbon & growth analytics"
        case .orchard: return "Yield & harvest analytics"
        case .pond: return "Water chemistry & life"
        case .garden: return "Soil, beds & companions"
        case .greenhouse: return "Climate & crop control"
        case .agriculture: return "Field analytics & yield forecast"
        case .home: return "Devices, energy & security"
        default: return "Analytics"
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                summaryCard
                if hasModuleDetail { moduleDetailButton }
                if !insights.isEmpty { insightStrip }
                entityFlow
            }
            .padding(Spacing.md)
            .padding(.top, 80)
            .padding(.bottom, 120)
        }
        .sheet(isPresented: $showModuleDetail) {
            Group {
                switch module {
                case .forest: ForestView(twin: twin)
                case .orchard: OrchardView(twin: twin)
                case .pond: PondDetailView(twin: twin)
                case .garden: GardenView(twin: twin)
                case .greenhouse: GreenhouseView(twin: twin)
                case .agriculture: AgricultureView(twin: twin)
                case .home: HomeView(twin: twin)
                default: EmptyView()
                }
            }
            .presentationDetents([.large])
            .presentationBackground(.clear)
            .presentationDragIndicator(.visible)
        }
    }

    private var moduleDetailButton: some View {
        Button { showModuleDetail = true } label: {
            HStack {
                Image(systemName: "chart.bar.xaxis").foregroundStyle(module.tint)
                Text(moduleDetailLabel).font(.prvioLabel())
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(Spacing.md)
            .liquidGlass(.raised, tint: module.tint, interactive: false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(moduleDetailLabel)
        .accessibilityHint("Opens detailed analytics for \(module.title)")
    }

    // MARK: - Summary

    private var summaryCard: some View {
        GlassCard(depth: .modal, tint: module.tint) {
            HStack(spacing: Spacing.lg) {
                HealthRing(score: twin.averageHealth(for: module), lineWidth: 12)
                    .frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: 6) {
                    Text(module.title).font(.prvioTitle())
                    Text("\(entities.count) entities monitored").font(.prvioLabel()).foregroundStyle(.secondary)
                    Text(summaryLine).font(.prvioCaption()).foregroundStyle(module.tint)
                }
                Spacer()
            }
        }
    }

    private var summaryLine: String {
        let stressed = entities.filter { $0.health.status == .stressed || $0.health.status == .critical }.count
        return stressed == 0 ? "All healthy" : "\(stressed) need attention"
    }

    // MARK: - Insights

    private var insightStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                ForEach(insights) { insight in
                    GlassCard(tint: module.tint) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(insight.title, systemImage: insight.severity.symbol)
                                .font(.prvioLabel()).lineLimit(2)
                            Text(insight.detail).font(.prvioCaption())
                                .foregroundStyle(.secondary).lineLimit(3)
                        }
                        .frame(width: 240, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Entity Flow (tap → back to map)

    private var entityFlow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)], spacing: Spacing.md) {
            ForEach(entities) { entity in
                EntityCell(entity: entity, tint: module.tint) { onSelectEntity(entity) }
            }
        }
    }
}

// MARK: - Entity cell (extracted to keep LazyVGrid body type-checker-friendly)

private struct EntityCell: View {
    var entity: PropertyEntity
    var tint: Color
    var onSelect: () -> Void

    var body: some View {
        Button { onSelect() } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: entity.kind.symbol)
                        .foregroundStyle(entity.health.score.healthColor)
                    Spacer()
                    Circle()
                        .fill(entity.health.score.healthColor)
                        .frame(width: 10, height: 10)
                }
                Text(entity.name).font(.prvioLabel()).lineLimit(1)
                metricLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .liquidGlass(.raised, tint: tint, interactive: false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entity.name)
        .accessibilityValue(entity.primaryMetric.map { "\($0.value) \($0.label)" }
            ?? "\(Int(entity.health.score * 100)) percent health")
        .accessibilityHint("Navigates to \(entity.name) on the map")
    }

    @ViewBuilder private var metricLine: some View {
        if let m = entity.primaryMetric {
            HStack(spacing: 3) {
                Text(m.value)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(tint)
                Text(m.label).font(.prvioCaption()).foregroundStyle(.secondary)
            }
        } else {
            Text("\(Int(entity.health.score * 100))% health")
                .font(.prvioCaption()).foregroundStyle(.secondary)
        }
    }
}
