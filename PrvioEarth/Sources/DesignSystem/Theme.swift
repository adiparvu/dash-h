//
//  Theme.swift
//  PRVIO EARTH
//
//  Color, typography and spacing tokens for the PRVIO Earth design system.
//  Colors are semantic and adapt to the Digital Twin context (forest,
//  pond, orchard, energy) rather than being raw hex values scattered
//  through views.
//

import SwiftUI

// MARK: - Palette

// Declared on `ShapeStyle where Self == Color` (not plain `Color`) so the
// palette resolves both as `Color.prvioMist` AND via leading-dot in any
// ShapeStyle context — `.foregroundStyle(.healthThriving)`, `.fill(.domainPond)`,
// ternaries, etc. — exactly like Apple's built-in `.red` / `.secondary`.
public extension ShapeStyle where Self == Color {
    // Brand
    static var prvioMist: Color     { Color(red: 0.62, green: 0.78, blue: 0.86) }
    static var prvioDeep: Color     { Color(red: 0.05, green: 0.13, blue: 0.18) }
    static var prvioHorizon: Color  { Color(red: 0.40, green: 0.62, blue: 0.74) }

    // Domain accents — each Smart module owns a hue
    static var domainForest: Color     { Color(red: 0.20, green: 0.55, blue: 0.34) }
    static var domainOrchard: Color    { Color(red: 0.86, green: 0.52, blue: 0.24) }
    static var domainPond: Color       { Color(red: 0.18, green: 0.60, blue: 0.70) }
    static var domainGarden: Color     { Color(red: 0.46, green: 0.68, blue: 0.30) }
    static var domainGreenhouse: Color { Color(red: 0.36, green: 0.74, blue: 0.58) }
    static var domainHome: Color       { Color(red: 0.52, green: 0.46, blue: 0.86) }
    static var domainEnergy: Color     { Color(red: 0.96, green: 0.78, blue: 0.20) }
    static var domainWater: Color      { Color(red: 0.30, green: 0.66, blue: 0.92) }
    static var domainSecurity: Color   { Color(red: 0.90, green: 0.34, blue: 0.40) }

    // Health / status spectrum
    static var healthThriving: Color { Color(red: 0.24, green: 0.80, blue: 0.44) }
    static var healthStable: Color   { Color(red: 0.62, green: 0.80, blue: 0.30) }
    static var healthStressed: Color { Color(red: 0.95, green: 0.72, blue: 0.20) }
    static var healthCritical: Color { Color(red: 0.92, green: 0.30, blue: 0.32) }
}

// MARK: - Typography

public extension Font {
    static func prvioTitle() -> Font   { .system(.largeTitle, design: .rounded).weight(.bold) }
    static func prvioHeadline() -> Font { .system(.title3, design: .rounded).weight(.semibold) }
    static func prvioMetric() -> Font   { .system(size: 34, weight: .semibold, design: .rounded) }
    static func prvioLabel() -> Font    { .system(.subheadline, design: .rounded).weight(.medium) }
    static func prvioCaption() -> Font  { .system(.caption, design: .rounded).weight(.medium) }
}

// MARK: - Spacing

public enum Spacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 36
}

// MARK: - Health Score → Color

public extension Double {
    /// Map a 0...1 health score to the PRVIO health spectrum.
    var healthColor: Color {
        switch self {
        case 0.8...:    return .healthThriving
        case 0.6..<0.8: return .healthStable
        case 0.35..<0.6: return .healthStressed
        default:        return .healthCritical
        }
    }
}
