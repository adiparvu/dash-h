//
//  OrchardView.swift
//  PRVIO EARTH
//
//  Smart Orchard management — phenophase tracker per section, treatment
//  calendar (fertilization, pruning), irrigation status and harvest
//  countdown. Reached from the Orchard module dashboard. Full yield
//  analytics accessible via the Analytics button.
//

import SwiftUI

public struct OrchardView: View {
    var twin: DigitalTwinEngine
    public init(twin: DigitalTwinEngine) { self.twin = twin }

    private var orchards: [PropertyEntity] {
        twin.entities.filter { if case .orchard = $0.detail { return true }; return false }
    }
    private var insights: [PrvioInsight] { twin.insights(for: .orchard) }

    @State private var showAnalytics = false

    private var totalExpectedYieldKg: Double {
        orchards.compactMap { e -> Double? in
            guard case .orchard(let o) = e.detail else { return nil }
            return o.expectedYieldKg
        }.reduce(0, +)
    }

    private var irrigatedCount: Int {
        orchards.filter { guard case .orchard(let o) = $0.detail else { return false }
            return o.irrigationActive }.count
    }

    private var readyCount: Int {
        orchards.filter { guard case .orchard(let o) = $0.detail else { return false }
            return o.phenophase == .ripening || o.phenophase == .harvest }.count
    }

    public var body: some View {
        AnalyticsScaffold(title: "Orchard", tint: .domainOrchard) {
            StatRow(stats: [
                .init(label: "Sections",  value: "\(orchards.count)",           icon: "apple.logo"),
                .init(label: "Expected",  value: "\(Int(totalExpectedYieldKg))", unit: "kg", icon: "scalemass.fill"),
                .init(label: "Irrigating", value: "\(irrigatedCount)/\(orchards.count)", icon: "spigot.fill"),
            ], tint: .domainOrchard)

            if readyCount > 0 { HarvestReadyBanner(count: readyCount) }

            OrchardPhenophaseTimeline(orchards: orchards)

            ForEach(orchards) { entity in
                if case .orchard(let profile) = entity.detail {
                    OrchardSectionCard(entity: entity, profile: profile)
                }
            }

            OrchardTreatmentCard(orchards: orchards)

            InsightFootnote(
                text: insights.first.map { $0.title + ". " + ($0.recommendation ?? "") }
                    ?? "PRVIO tracks phenophase progress and correlates with weather to optimise picking windows and treatment timing.",
                tint: .domainOrchard)

            GlassButton("Analytics", systemImage: "chart.bar.xaxis", tint: .domainOrchard) {
                showAnalytics = true
            }
        }
        .sheet(isPresented: $showAnalytics) {
            OrchardAnalyticsView(twin: twin)
                .presentationDetents([.large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Harvest ready banner

private struct HarvestReadyBanner: View {
    var count: Int
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "basket.fill").foregroundStyle(.domainOrchard)
            Text("\(count) section\(count == 1 ? "" : "s") ready to harvest")
                .font(.prvioLabel())
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: .domainOrchard, interactive: false)
    }
}

// MARK: - Phenophase timeline

private struct OrchardPhenophaseTimeline: View {
    var orchards: [PropertyEntity]

    private typealias Phase = OrchardProfile.Phenophase
    private let phases: [Phase] = [.dormant, .budding, .flowering, .fruiting, .ripening, .harvest]

    private var counts: [Phase: Int] {
        orchards.reduce(into: [:]) { result, e in
            if case .orchard(let o) = e.detail { result[o.phenophase, default: 0] += 1 }
        }
    }

    private var dominant: Phase? {
        counts.max(by: { $0.value < $1.value })?.key
    }

    var body: some View {
        GlassCard(tint: .domainOrchard) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Phenophase").font(.prvioCaption()).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(phases, id: \.self) { phase in
                        PhaseCell(phase: phase,
                                  count: counts[phase] ?? 0,
                                  isActive: phase == dominant)
                    }
                }
            }
        }
    }
}

private struct PhaseCell: View {
    var phase: OrchardProfile.Phenophase
    var count: Int
    var isActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: phaseSymbol)
                .font(.caption)
                .foregroundStyle(isActive ? phaseColor : .secondary)
                .padding(6)
                .background(Circle().fill(
                    isActive ? phaseColor.opacity(0.2) : Color.primary.opacity(0.06)))
            Text(phase.rawValue.prefix(3).uppercased())
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(isActive ? phaseColor : .secondary)
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 8))
                    .foregroundStyle(isActive ? phaseColor : .tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(phase.rawValue) phase, \(count) sections")
    }

    private var phaseSymbol: String {
        switch phase {
        case .dormant:   return "zzz"
        case .budding:   return "leaf"
        case .flowering: return "camera.macro"
        case .fruiting:  return "circle.fill"
        case .ripening:  return "sun.max.fill"
        case .harvest:   return "basket.fill"
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .dormant:   return .secondary
        case .budding:   return .domainGarden
        case .flowering: return Color(hue: 0.95, saturation: 0.6, brightness: 0.9)
        case .fruiting:  return .domainOrchard
        case .ripening:  return Color.orange
        case .harvest:   return .healthThriving
        }
    }
}

// MARK: - Section card

private struct OrchardSectionCard: View {
    var entity: PropertyEntity
    var profile: OrchardProfile

    var body: some View {
        GlassCard(tint: .domainOrchard) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "apple.logo").foregroundStyle(.domainOrchard)
                    Text(entity.name).font(.prvioLabel())
                    Spacer()
                    PhaseBadge(phase: profile.phenophase)
                }
                Text(profile.species)
                    .font(.prvioCaption()).foregroundStyle(.secondary)
                HStack(spacing: Spacing.md) {
                    Label(String(format: "%.0f kg", profile.expectedYieldKg),
                          systemImage: "scalemass.fill")
                    Label(profile.irrigationActive ? "Irrigating" : "Dry",
                          systemImage: profile.irrigationActive ? "spigot.fill" : "spigot")
                        .foregroundStyle(profile.irrigationActive ? .domainWater : .secondary)
                }
                .font(.prvioCaption()).foregroundStyle(.secondary)
                HStack {
                    Label("Harvest in \(daysUntil(profile.nextHarvest))d",
                          systemImage: "calendar")
                        .font(.prvioCaption()).foregroundStyle(.domainOrchard)
                    Spacer()
                    Text(String(format: "%.0f%%", entity.health.score * 100))
                        .font(.prvioCaption())
                        .foregroundStyle(entity.health.score.healthColor)
                }
            }
        }
    }

    private func daysUntil(_ date: Date) -> Int {
        max(0, Int(date.timeIntervalSinceNow / 86_400))
    }
}

private struct PhaseBadge: View {
    var phase: OrchardProfile.Phenophase
    var body: some View {
        Text(phase.rawValue.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(badgeColor.opacity(0.18)))
            .foregroundStyle(badgeColor)
    }
    private var badgeColor: Color {
        switch phase {
        case .dormant:   return .secondary
        case .budding:   return .domainGarden
        case .flowering: return Color(hue: 0.95, saturation: 0.6, brightness: 0.9)
        case .fruiting:  return .domainOrchard
        case .ripening:  return Color.orange
        case .harvest:   return .healthThriving
        }
    }
}

// MARK: - Treatment schedule

private struct OrchardTreatmentCard: View {
    var orchards: [PropertyEntity]

    private var nextFertilization: Date? {
        orchards.compactMap { e -> Date? in
            guard case .orchard(let o) = e.detail else { return nil }
            return o.nextFertilization
        }.min()
    }

    private var nextPruning: Date? {
        orchards.compactMap { e -> Date? in
            guard case .orchard(let o) = e.detail else { return nil }
            return o.nextPruning
        }.min()
    }

    var body: some View {
        GlassCard(tint: .domainOrchard) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Treatment Schedule").font(.prvioCaption()).foregroundStyle(.secondary)
                if let fert = nextFertilization {
                    OrchardTreatmentRow(icon: "leaf.fill", label: "Next Fertilization",
                                       date: fert, tint: .healthThriving)
                }
                if let prune = nextPruning {
                    OrchardTreatmentRow(icon: "scissors", label: "Next Pruning",
                                       date: prune, tint: .domainForest)
                }
                if nextFertilization == nil && nextPruning == nil {
                    Text("No treatments scheduled").font(.prvioCaption()).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct OrchardTreatmentRow: View {
    var icon: String
    var label: String
    var date: Date
    var tint: Color
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 22)
            Text(label).font(.prvioCaption())
            Spacer()
            Text(date, style: .relative)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(tint)
        }
    }
}
