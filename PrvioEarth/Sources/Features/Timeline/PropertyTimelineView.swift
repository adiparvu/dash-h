//
//  PropertyTimelineView.swift
//  PRVIO EARTH
//
//  A unified, filterable chronological feed of everything that happened
//  on the property: automation fires, AI insights (warnings+) and advisory
//  notes — in one Liquid Glass timeline so the owner always knows what
//  PRVIO acted on and why. Backed entirely by live DigitalTwinEngine state
//  so it refreshes in real time as the twin evolves.
//

import SwiftUI

public struct PropertyTimelineView: View {
    var twin: DigitalTwinEngine
    public init(twin: DigitalTwinEngine) { self.twin = twin }

    enum Filter: String, CaseIterable { case all = "All", automations = "Automations", insights = "Insights", alerts = "Alerts" }
    @State private var filter: Filter = .all

    // MARK: - Unified event model

    struct TimelineEvent: Identifiable {
        enum Kind { case automation, insight, alert }
        let id: UUID
        var kind: Kind
        var title: String
        var detail: String
        var module: PropertyModule
        var severity: PrvioInsight.Severity?
        var firedAt: Date

        var severityLabel: String {
            switch severity {
            case .info: return "Info"
            case .advisory: return "Advisory"
            case .warning: return "Warning"
            case .critical: return "Critical"
            case .none: return ""
            }
        }

        var symbol: String {
            switch kind {
            case .automation: return "bolt.fill"
            case .insight:    return "lightbulb.fill"
            case .alert:      return severity?.symbol ?? "exclamationmark.triangle.fill"
            }
        }
    }

    // MARK: - Event aggregation

    private var allEvents: [TimelineEvent] {
        var events: [TimelineEvent] = []

        for e in twin.automationFiredEvents {
            events.append(TimelineEvent(
                id: e.id, kind: .automation,
                title: e.automationName,
                detail: "Triggered: \(e.triggerTitle)",
                module: e.module, severity: nil,
                firedAt: e.firedAt))
        }

        for insight in twin.insights {
            let kind: TimelineEvent.Kind = insight.severity >= .warning ? .alert : .insight
            events.append(TimelineEvent(
                id: insight.id, kind: kind,
                title: insight.title, detail: insight.detail,
                module: insight.module, severity: insight.severity,
                firedAt: insight.createdAt))
        }

        return events.sorted { $0.firedAt > $1.firedAt }
    }

    private var filteredEvents: [TimelineEvent] {
        switch filter {
        case .all:          return allEvents
        case .automations:  return allEvents.filter { $0.kind == .automation }
        case .insights:     return allEvents.filter { $0.kind == .insight }
        case .alerts:       return allEvents.filter { $0.kind == .alert }
        }
    }

    /// Day-grouped events sorted newest first.
    private var groupedEvents: [(label: String, events: [TimelineEvent])] {
        let cal = Calendar.current
        var groups: [String: [TimelineEvent]] = [:]
        for event in filteredEvents {
            let key: String
            if cal.isDateInToday(event.firedAt)           { key = "Today" }
            else if cal.isDateInYesterday(event.firedAt)  { key = "Yesterday" }
            else { key = event.firedAt.formatted(.dateTime.weekday(.wide).day().month()) }
            groups[key, default: []].append(event)
        }
        let pinned = ["Today", "Yesterday"]
        return groups.keys
            .sorted { a, b in
                let ai = pinned.firstIndex(of: a) ?? Int.max
                let bi = pinned.firstIndex(of: b) ?? Int.max
                if ai != bi { return ai < bi }
                return a > b
            }
            .map { (label: $0, events: groups[$0]!) }
    }

    // MARK: - Export

    private var exportSummary: String {
        var lines = [
            "PRVIO EARTH — Timeline Export",
            "Filter: \(filter.rawValue)",
            "Date: \(Date().formatted(.dateTime.day().month().year()))",
            String(repeating: "-", count: 42),
        ]
        for event in filteredEvents {
            let stamp = event.firedAt.formatted(.dateTime.hour().minute().day().month())
            lines.append("\(stamp)  [\(event.module.title)]  \(event.title)")
            lines.append("  \(event.detail)")
        }
        if filteredEvents.isEmpty { lines.append("No events recorded.") }
        return lines.joined(separator: "\n")
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                headerSection
                filterStrip
                if filteredEvents.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedEvents, id: \.label) { group in
                        daySection(group)
                    }
                }
            }
            .padding(Spacing.lg)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial).ignoresSafeArea()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Timeline").font(.prvioTitle())
                Text("\(allEvents.count) events on record")
                    .font(.prvioCaption()).foregroundStyle(.secondary)
            }
            Spacer()
            ShareLink(item: exportSummary,
                      subject: Text("PRVIO Timeline"),
                      message: Text("Exported from PRVIO EARTH")) {
                Image(systemName: "square.and.arrow.up")
                    .font(.prvioLabel())
                    .padding(Spacing.sm)
                    .liquidGlass(.raised, tint: .prvioHorizon, interactive: false)
            }
            .buttonStyle(.plain)
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(Filter.allCases, id: \.self) { f in
                    filterChip(f)
                }
            }
        }
    }

    private func filterChip(_ f: Filter) -> some View {
        Button { withAnimation(.prvioMorph) { filter = f } } label: {
            Text(f.rawValue)
                .font(.prvioLabel())
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .liquidGlass(filter == f ? .raised : .floating,
                             tint: filter == f ? .prvioHorizon : .prvioMist,
                             interactive: false)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        GlassCard {
            HStack {
                Spacer()
                VStack(spacing: Spacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40)).foregroundStyle(.healthThriving)
                    Text("All quiet").font(.prvioLabel())
                    Text("No \(filter == .all ? "" : filter.rawValue.lowercased() + " ")events recorded yet.")
                        .font(.prvioCaption()).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(.vertical, Spacing.xl)
        }
    }

    private func daySection(_ group: (label: String, events: [TimelineEvent])) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(group.label)
                .font(.prvioCaption().weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            ForEach(group.events) { event in
                TimelineEventRow(event: event)
            }
        }
    }
}

// MARK: - Event row

private struct TimelineEventRow: View {
    var event: PropertyTimelineView.TimelineEvent

    private var accentColor: Color {
        guard event.kind == .alert, let sev = event.severity else { return event.module.tint }
        return sev == .critical ? .healthCritical : .healthStressed
    }

    var body: some View {
        GlassCard(tint: accentColor) {
            HStack(alignment: .top, spacing: Spacing.md) {
                iconBadge
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(event.title).font(.prvioLabel()).lineLimit(2)
                        Spacer(minLength: 4)
                        Text(event.firedAt, style: .relative)
                            .font(.prvioCaption()).foregroundStyle(.secondary)
                    }
                    Text(event.detail)
                        .font(.prvioCaption()).foregroundStyle(.secondary).lineLimit(2)
                    pills
                }
            }
        }
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.16))
                .frame(width: 40, height: 40)
            Image(systemName: event.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accentColor)
        }
    }

    private var pills: some View {
        HStack(spacing: 6) {
            pill(event.module.title, color: event.module.tint)
            if let sev = event.severity, sev >= .warning {
                pill(event.severityLabel, color: accentColor)
            }
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}
