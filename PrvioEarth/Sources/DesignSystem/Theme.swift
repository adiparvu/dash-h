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

public extension Color {
    // Brand
    static let prvioMist     = Color(red: 0.62, green: 0.78, blue: 0.86)
    static let prvioDeep     = Color(red: 0.05, green: 0.13, blue: 0.18)
    static let prvioHorizon  = Color(red: 0.40, green: 0.62, blue: 0.74)

    // Domain accents — each Smart module owns a hue
    static let domainForest    = Color(red: 0.20, green: 0.55, blue: 0.34)
    static let domainOrchard   = Color(red: 0.86, green: 0.52, blue: 0.24)
    static let domainPond      = Color(red: 0.18, green: 0.60, blue: 0.70)
    static let domainGarden    = Color(red: 0.46, green: 0.68, blue: 0.30)
    static let domainGreenhouse = Color(red: 0.36, green: 0.74, blue: 0.58)
    static let domainHome      = Color(red: 0.52, green: 0.46, blue: 0.86)
    static let domainEnergy    = Color(red: 0.96, green: 0.78, blue: 0.20)
    static let domainWater     = Color(red: 0.30, green: 0.66, blue: 0.92)
    static let domainSecurity  = Color(red: 0.90, green: 0.34, blue: 0.40)

    // Health / status spectrum
    static let healthThriving = Color(red: 0.24, green: 0.80, blue: 0.44)
    static let healthStable   = Color(red: 0.62, green: 0.80, blue: 0.30)
    static let healthStressed = Color(red: 0.95, green: 0.72, blue: 0.20)
    static let healthCritical = Color(red: 0.92, green: 0.30, blue: 0.32)
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
