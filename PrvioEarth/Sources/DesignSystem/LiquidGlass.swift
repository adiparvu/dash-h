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
///
/// Fully respects accessibility settings: with **Reduce Transparency** the
/// material becomes an opaque, high-contrast surface; with **Reduce Motion**
/// the specular sweep is held static. The surface still reads as Liquid Glass
/// in both modes — it just stops being see-through / animated.
public struct LiquidGlassBackground: ViewModifier {
    var depth: GlassDepth
    var tint: Color
    var isInteractive: Bool

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var highlightPhase: CGFloat = -1

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: depth.cornerRadius, style: .continuous) }

    public func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if reduceTransparency {
                        // Opaque, high-contrast fallback (no blur, no see-through).
                        shape.fill(scheme == .dark ? Color.prvioDeep : Color.white)
                        shape.fill(tint.opacity(scheme == .dark ? 0.32 : 0.16))
                    } else {
                        // Base frosted material
                        shape.fill(.ultraThinMaterial)
                        // Adaptive tint wash
                        shape.fill(tint.opacity(scheme == .dark ? 0.18 : 0.10))
                        // Dynamic specular reflection sweeping across the surface
                        // (held static when Reduce Motion is on).
                        specularHighlight
                    }
                }
            }
            .overlay {
                // Luminous adaptive border — stronger when opaque for contrast.
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(reduceTransparency ? 0.7 : 0.55), .white.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: reduceTransparency ? 1.2 : 0.8)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.22), radius: depth.shadowRadius, y: depth.shadowY)
            .onAppear {
                guard isInteractive, !reduceMotion else { return }
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    highlightPhase = 1.4
                }
            }
    }

    private var specularHighlight: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(depth.highlightOpacity), .white.opacity(0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: w * 0.6)
            // Static, centred sheen under Reduce Motion; animated sweep otherwise.
            .offset(x: (reduceMotion ? 0.2 : highlightPhase) * w)
            .blur(radius: 8)
            .blendMode(.plusLighter)
            .mask(shape)
            .allowsHitTesting(false)
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
