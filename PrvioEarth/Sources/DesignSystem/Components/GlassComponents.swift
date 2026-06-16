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
    }
}

// MARK: - Health Ring

/// Apple-Activity-style ring expressing a 0...1 health score.
public struct HealthRing: View {
    var score: Double
    var lineWidth: CGFloat = 10
    @State private var animated: Double = 0

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
        .onAppear { withAnimation(.prvioFluid.delay(0.1)) { animated = score } }
    }
}
