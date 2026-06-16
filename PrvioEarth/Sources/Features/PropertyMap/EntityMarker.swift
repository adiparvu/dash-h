//
//  EntityMarker.swift
//  PRVIO EARTH
//
//  The tappable, object-centric annotation rendered for every entity on
//  the Digital Twin map. Pulses with live health, morphs on selection and
//  dims when PRVIO Intelligence focuses elsewhere. This is the unit of
//  spatial interaction — the user manages the property by tapping these.
//

import SwiftUI

public struct EntityMarker: View {
    var entity: PropertyEntity
    var isSelected: Bool
    var isHighlighted: Bool
    var isDimmed: Bool
    var overlayTint: Color?
    var onTap: () -> Void

    @State private var pulse = false

    private var tint: Color { overlayTint ?? entity.health.score.healthColor }

    public var body: some View {
        Button(action: onTap) {
            ZStack {
                // Live health halo
                Circle()
                    .fill(tint.opacity(0.25))
                    .frame(width: isSelected ? 64 : 48, height: isSelected ? 64 : 48)
                    .scaleEffect(pulse ? 1.18 : 0.92)
                    .opacity(pulse ? 0.2 : 0.5)

                // Glass disc
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().strokeBorder(tint, lineWidth: 2))
                    .frame(width: isSelected ? 44 : 34, height: isSelected ? 44 : 34)
                    .shadow(color: tint.opacity(0.5), radius: isSelected ? 10 : 4)

                Image(systemName: entity.kind.symbol)
                    .font(.system(size: isSelected ? 18 : 14, weight: .semibold))
                    .foregroundStyle(tint)

                // Highlight ring (Intelligence focus)
                if isHighlighted {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2.5)
                        .frame(width: 52, height: 52)
                        .shadow(color: .white.opacity(0.8), radius: 6)
                }
            }
            .opacity(isDimmed ? 0.3 : 1)
            .scaleEffect(isDimmed ? 0.85 : 1)
        }
        .buttonStyle(.plain)
        .animation(.prvioMorph, value: isSelected)
        .animation(.prvioMorph, value: isDimmed)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
