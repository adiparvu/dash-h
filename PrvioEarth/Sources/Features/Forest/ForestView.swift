//
//  ForestView.swift
//  PRVIO EARTH
//
//  Smart Forest management — per-tree cards with carbon tracking, pest
//  status, soil moisture and growth stats. Carbon sequestration progress
//  ring shows the property's yearly target. Deep species analytics are
//  one tap away via the Analytics button. Reached from the Forest
//  module dashboard.
//

import SwiftUI

public struct ForestView: View {
    var twin: DigitalTwinEngine
    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var trees: [PropertyEntity] {
        twin.entities.filter { if case .tree = $0.detail { return true }; return false }
    }
    private var insights: [PrvioInsight] { twin.insights(for: .forest) }

    @State private var showAnalytics = false

    private var totalCarbonKg: Double {
        trees.compactMap { e -> Double? in
            guard case .tree(let t) = e.detail else { return nil }
            return t.carbonStorageKg
        }.reduce(0, +)
    }

    private var pestCount: Int {
        trees.filter { guard case .tree(let t) = $0.detail else { return false }
            return t.pestDetected }.count
    }

    private var avgHeightM: Double {
        let hs = trees.compactMap { e -> Double? in
            guard case .tree(let t) = e.detail else { return nil }
            return t.heightMeters
        }
        return hs.isEmpty ? 0 : hs.reduce(0, +) / Double(hs.count)
    }

    public var body: some View {
        AnalyticsScaffold(title: "Forest", tint: .domainForest) {
            StatRow(stats: [
                .init(label: "Trees",  value: "\(trees.count)",                          icon: "tree.fill"),
                .init(label: "Carbon", value: "\(Int(totalCarbonKg))", unit: "kg",        icon: "leaf.fill"),
                .init(label: "Avg Ht", value: String(format: "%.1f", avgHeightM), unit: "m", icon: "arrow.up.to.line"),
            ], tint: .domainForest)

            if pestCount > 0 { ForestPestBanner(count: pestCount) }

            ForestCarbonRing(carbonKg: totalCarbonKg,
                             targetKg: Double(max(1, trees.count)) * 500)

            ForestSpeciesCard(trees: trees)

            ForEach(trees) { entity in
                if case .tree(let profile) = entity.detail {
                    ForestTreeCard(entity: entity, profile: profile)
                }
            }

            InsightFootnote(
                text: insights.first.map { $0.title + ". " + ($0.recommendation ?? "") }
                    ?? "PRVIO monitors canopy density, pest pressure and soil health to optimise your forest's carbon sequestration.",
                tint: .domainForest)

            GlassButton("Analytics", systemImage: "chart.bar.xaxis", tint: .domainForest) {
                showAnalytics = true
            }
        }
        .sheet(isPresented: $showAnalytics) {
            ForestAnalyticsView(twin: twin)
                .presentationDetents([.large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Pest alert banner

private struct ForestPestBanner: View {
    var count: Int
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "ant.fill").foregroundStyle(.domainSecurity)
            Text("Pest detected in \(count) tree\(count == 1 ? "" : "s")")
                .font(.prvioLabel())
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: .domainSecurity, interactive: false)
    }
}

// MARK: - Carbon sequestration ring

private struct ForestCarbonRing: View {
    var carbonKg: Double
    var targetKg: Double

    private var fraction: Double { min(1, carbonKg / max(1, targetKg)) }

    var body: some View {
        GlassCard(tint: .domainForest) {
            HStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .stroke(Color.domainForest.opacity(0.14), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(Color.domainForest.gradient,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int(fraction * 100))%")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.domainForest)
                        Text("target").font(.prvioCaption()).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Carbon sequestered").font(.prvioLabel())
                    Text("\(Int(carbonKg)) kg")
                        .font(.prvioMetric()).foregroundStyle(.domainForest)
                    Text("Yearly target: \(Int(targetKg)) kg")
                        .font(.prvioCaption()).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Species breakdown card

private struct ForestSpeciesCard: View {
    var trees: [PropertyEntity]

    private var counts: [(species: String, count: Int)] {
        var dict: [String: Int] = [:]
        for e in trees {
            if case .tree(let t) = e.detail { dict[t.species, default: 0] += 1 }
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }

    var body: some View {
        if !counts.isEmpty {
            GlassCard(tint: .domainForest) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Species composition").font(.prvioCaption()).foregroundStyle(.secondary)
                    ForEach(counts, id: \.species) { item in
                        HStack {
                            Image(systemName: "tree.fill")
                                .foregroundStyle(.domainForest).frame(width: 20)
                            Text(item.species).font(.prvioLabel())
                            Spacer()
                            Text("\(item.count)")
                                .font(.prvioCaption().monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Individual tree card

private struct ForestTreeCard: View {
    var entity: PropertyEntity
    var profile: TreeProfile

    var body: some View {
        GlassCard(tint: .domainForest) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "tree.fill").foregroundStyle(.domainForest)
                    Text(entity.name).font(.prvioLabel())
                    Spacer()
                    if profile.pestDetected {
                        Label("Pest", systemImage: "ant.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.domainSecurity)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(Color.domainSecurity.opacity(0.15)))
                    }
                }
                Text(profile.species)
                    .font(.prvioCaption()).foregroundStyle(.secondary)
                HStack(spacing: Spacing.md) {
                    Label(String(format: "%.1f m", profile.heightMeters),
                          systemImage: "arrow.up.to.line")
                    Label("\(Int(profile.carbonStorageKg)) kg CO₂",
                          systemImage: "leaf.fill")
                        .foregroundStyle(.domainForest)
                    Label("\(profile.ageYears) yr",
                          systemImage: "calendar")
                }
                .font(.prvioCaption()).foregroundStyle(.secondary)
                HStack {
                    Label(String(format: "Soil %.0f%%", profile.soilMoisture * 100),
                          systemImage: "drop.fill")
                        .font(.prvioCaption())
                        .foregroundStyle(soilTint)
                    Spacer()
                    Text(String(format: "%.0f%%", entity.health.score * 100))
                        .font(.prvioCaption())
                        .foregroundStyle(entity.health.score.healthColor)
                }
            }
        }
    }

    private var soilTint: Color {
        profile.soilMoisture < 0.3 ? .healthStressed
            : profile.soilMoisture > 0.7 ? .domainWater
            : .secondary
    }
}
