//
//  LiquidGlass.swift
//  PRVIO EARTH
//
//  The core of the iOS 27 "Liquid Glass" design language.
//  Provides adaptive, depth-aware translucent surfaces with dynamic
//  reflections, physics-based morphing and contextual blur.
//
//  Everything in PRVIO EARTH that floats above the Digital Twin map is
//  rendered on Liquid Glass. These primitives are the single source of
//  truth for that material so the whole app feels like one Apple surface.
//

import SwiftUI

// MARK: - Glass Material Levels

/// Depth tiers for Liquid Glass surfaces. Higher tiers float closer to the
/// user, receive stronger reflections and cast deeper shadows.
public enum GlassDepth: CGFloat, CaseIterable, Sendable {
    case ambient = 0      // Background chrome, weather scrims
    case raised = 1       // Floating cards, object pills
    case floating = 2     // Navigation bar, search field
    case modal = 3        // Detail sheets, AI assistant

    var blurRadius: CGFloat {
        switch self {
        case .ambient: return 12
        case .raised: return 24
        case .floating: return 36
        case .modal: return 50
        }
    }

    var shadowRadius: CGFloat { rawValue * 8 + 6 }
    var shadowY: CGFloat { rawValue * 4 + 2 }
    var highlightOpacity: Double { 0.25 + rawValue * 0.12 }
    var cornerRadius: CGFloat { 22 + rawValue * 4 }
}

// MARK: - Liquid Glass Material

/// A reusable view-modifier rendering the signature PRVIO Liquid Glass
/// surface: frosted translucency + a moving specular highlight + a thin
/// luminous border that adapts to the content behind it.
public struct LiquidGlassBackground: ViewModifier {
    var depth: GlassDepth
    var tint: Color
    var isInteractive: Bool

    @Environment(\.colorScheme) private var scheme
    @State private var highlightPhase: CGFloat = -1

    public func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Base frosted material
                    RoundedRectangle(cornerRadius: depth.cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Adaptive tint wash
                    RoundedRectangle(cornerRadius: depth.cornerRadius, style: .continuous)
                        .fill(tint.opacity(scheme == .dark ? 0.18 : 0.10))

                    // Dynamic specular reflection sweeping across the surface
                    GeometryReader { geo in
                        let w = geo.size.width
                        LinearGradient(
                            colors: [.white.opacity(0), .white.opacity(depth.highlightOpacity), .white.opacity(0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: w * 0.6)
                        .offset(x: highlightPhase * w)
                        .blur(radius: 8)
                        .blendMode(.plusLighter)
                        .mask(RoundedRectangle(cornerRadius: depth.cornerRadius, style: .continuous))
                        .allowsHitTesting(false)
                    }
                }
            }
            .overlay {
                // Luminous adaptive border
                RoundedRectangle(cornerRadius: depth.cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: depth.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: depth.shadowRadius, y: depth.shadowY)
            .onAppear {
                guard isInteractive else { return }
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    highlightPhase = 1.4
                }
            }
    }
}

public extension View {
    /// Apply the PRVIO Liquid Glass material.
    func liquidGlass(
        _ depth: GlassDepth = .raised,
        tint: Color = .prvioMist,
        interactive: Bool = true
    ) -> some View {
        modifier(LiquidGlassBackground(depth: depth, tint: tint, isInteractive: interactive))
    }
}

// MARK: - Contextual Morph

/// A physics-based spring used everywhere objects morph between states
/// (pill → sheet, collapsed → expanded). Centralised so motion feels
/// consistent across the whole Digital Twin.
public extension Animation {
    static var prvioMorph: Animation { .spring(response: 0.45, dampingFraction: 0.82) }
    static var prvioFluid: Animation { .interpolatingSpring(stiffness: 180, damping: 22) }
    static var prvioSnappy: Animation { .spring(response: 0.3, dampingFraction: 0.7) }
}
