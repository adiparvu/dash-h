//
//  FloatingNavBar.swift
//  PRVIO EARTH
//
//  The floating, morphing module switcher that hovers over the Digital
//  Twin map. Replaces the traditional tab bar — it is object/context
//  centric and collapses out of the way when the user explores the map.
//

import SwiftUI

public enum PropertyModule: String, CaseIterable, Identifiable, Sendable {
    case map, forest, orchard, pond, garden, greenhouse, home, intelligence

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .map: return "Twin"
        case .forest: return "Forest"
        case .orchard: return "Orchard"
        case .pond: return "Pond"
        case .garden: return "Garden"
        case .greenhouse: return "Glass House"
        case .home: return "Home"
        case .intelligence: return "PRVIO"
        }
    }

    var icon: String {
        switch self {
        case .map: return "globe.americas.fill"
        case .forest: return "tree.fill"
        case .orchard: return "apple.logo"
        case .pond: return "drop.fill"
        case .garden: return "camera.macro"
        case .greenhouse: return "leaf.fill"
        case .home: return "house.fill"
        case .intelligence: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .map: return .prvioHorizon
        case .forest: return .domainForest
        case .orchard: return .domainOrchard
        case .pond: return .domainPond
        case .garden: return .domainGarden
        case .greenhouse: return .domainGreenhouse
        case .home: return .domainHome
        case .intelligence: return .prvioMist
        }
    }
}

public struct FloatingNavBar: View {
    @Binding var selection: PropertyModule
    var collapsed: Bool
    @Namespace private var ns

    public init(selection: Binding<PropertyModule>, collapsed: Bool = false) {
        self._selection = selection
        self.collapsed = collapsed
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: collapsed ? 0 : Spacing.xs) {
                ForEach(PropertyModule.allCases) { module in
                    let isSelected = module == selection
                    Button {
                        HapticEngine.selection()
                        withAnimation(.prvioMorph) { selection = module }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: module.icon)
                                .font(.system(size: 17, weight: .semibold))
                            if isSelected && !collapsed {
                                Text(module.title)
                                    .font(.prvioLabel())
                                    .fixedSize()
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.7))
                        .padding(.horizontal, isSelected ? 16 : 12)
                        .padding(.vertical, 12)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(module.tint.gradient)
                                    .matchedGeometryEffect(id: "nav.pill", in: ns)
                                    .shadow(color: module.tint.opacity(0.5), radius: 8, y: 3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
        }
        .liquidGlass(.floating, tint: selection.tint)
        .animation(.prvioMorph, value: collapsed)
    }
}
