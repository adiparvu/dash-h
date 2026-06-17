//
//  GlassComponents.swift
//  PRVIO EARTH
//
//  Reusable Liquid Glass component library. These are the building blocks
//  used by every screen so the app reads as a single cohesive surface.
//

import SwiftUI

// MARK: - Glass Card

/// A floating Liquid Glass container. The default surface for grouping
/// content above the Digital Twin map.
public struct GlassCard<Content: View>: View {
    var depth: GlassDepth
    var tint: Color
    @ViewBuilder var content: () -> Content

    public init(depth: GlassDepth = .raised, tint: Color = .prvioMist, @ViewBuilder content: @escaping () -> Content) {
        self.depth = depth
        self.tint = tint
        self.content = content
    }

    public var body: some View {
        content()
            .padding(Spacing.md)
            .liquidGlass(depth, tint: tint)
    }
}

// MARK: - Glass Capsule Button

public struct GlassButton: View {
    var title: String
    var systemImage: String?
    var tint: Color
    var action: () -> Void

    @State private var pressed = false

    public init(_ title: String, systemImage: String? = nil, tint: Color = .prvioHorizon, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.prvioLabel())
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 2)
            .liquidGlass(.floating, tint: tint, interactive: false)
            .scaleEffect(pressed ? 0.94 : 1)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { p in
            withAnimation(.prvioSnappy) { pressed = p }
        }, perform: {})
    }
}

// MARK: - Metric Tile

/// Compact live-metric readout used inside detail sheets and dashboards.
public struct MetricTile: View {
    var label: String
    var value: String
    var unit: String?
    var icon: String
    var tint: Color
    var trend: Trend?

    public enum Trend { case up, down, flat
        var symbol: String { self == .up ? "arrow.up.right" : self == .down ? "arrow.down.right" : "arrow.right" }
        var color: Color { self == .up ? .healthThriving : self == .down ? .healthCritical : .secondary }
    }

    public init(label: String, value: String, unit: String? = nil, icon: String, tint: Color, trend: Trend? = nil) {
        self.label = label; self.value = value; self.unit = unit
        self.icon = icon; self.tint = tint; self.trend = trend
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: icon).foregroundStyle(tint)
                Spacer()
                if let trend {
                    Image(systemName: trend.symbol).font(.caption).foregroundStyle(trend.color)
                }
            }
            Text(label).font(.prvioCaption()).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.prvioMetric())
                if let unit { Text(unit).font(.prvioLabel()).foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: tint, interactive: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)\(unit.map { " \($0)" } ?? "")")
    }
}

// MARK: - Analytics Scaffold (shared by all module detail views)

public struct AnalyticsScaffold<Content: View>: View {
    public var title: String
    public var tint: Color
    @ViewBuilder public var content: () -> Content

    public init(title: String, tint: Color, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.tint = tint; self.content = content
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(title).font(.prvioTitle())
                content()
            }
            .padding(Spacing.lg)
            .padding(.top, 40)
            .padding(.bottom, 60)
        }
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial).ignoresSafeArea()
        }
    }
}

public struct ChartCard<Content: View>: View {
    public var title: String
    public var tint: Color
    @ViewBuilder public var content: () -> Content

    public init(title: String, tint: Color, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.tint = tint; self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title).font(.prvioHeadline())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: tint, interactive: false)
    }
}

public struct AnalyticsStat: Identifiable {
    public let id = UUID()
    public var label: String
    public var value: String
    public var unit: String?
    public var icon: String

    public init(label: String, value: String, unit: String? = nil, icon: String) {
        self.label = label; self.value = value; self.unit = unit; self.icon = icon
    }
}

public struct StatRow: View {
    public var stats: [AnalyticsStat]
    public var tint: Color

    public init(stats: [AnalyticsStat], tint: Color) {
        self.stats = stats; self.tint = tint
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: stat.icon).foregroundStyle(tint)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(stat.value).font(.system(size: 24, weight: .semibold, design: .rounded))
                        if let unit = stat.unit { Text(unit).font(.prvioCaption()).foregroundStyle(.secondary) }
                    }
                    Text(stat.label).font(.prvioCaption()).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .liquidGlass(.raised, tint: tint, interactive: false)
            }
        }
    }
}

public struct RiskBadge: View {
    public var label: String
    public var count: Int
    public var icon: String
    public var tint: Color

    public init(label: String, count: Int, icon: String, tint: Color) {
        self.label = label; self.count = count; self.icon = icon; self.tint = tint
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon).foregroundStyle(count > 0 ? tint : .secondary)
            VStack(alignment: .leading) {
                Text("\(count)").font(.prvioHeadline())
                Text(label).font(.prvioCaption()).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: count > 0 ? tint : .prvioMist, interactive: false)
    }
}

public struct InsightFootnote: View {
    public var text: String
    public var tint: Color

    public init(text: String, tint: Color) {
        self.text = text; self.tint = tint
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "sparkles").foregroundStyle(tint)
            Text(text).font(.prvioCaption()).foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: tint, interactive: false)
    }
}

// MARK: - Health Ring

/// Apple-Activity-style ring expressing a 0...1 health score.
public struct HealthRing: View {
    var score: Double
    var lineWidth: CGFloat = 10
    @State private var animated: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(score: Double, lineWidth: CGFloat = 10) {
        self.score = score; self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animated)
                .stroke(
                    AngularGradient(colors: [score.healthColor.opacity(0.7), score.healthColor], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int(score * 100))")
                .font(.prvioHeadline())
                .contentTransition(.numericText())
        }
        .onAppear {
            if reduceMotion { animated = score }
            else { withAnimation(.prvioFluid.delay(0.1)) { animated = score } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Health")
        .accessibilityValue("\(Int(score * 100)) percent")
    }
}
