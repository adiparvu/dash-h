//
//  HapticEngine.swift
//  PRVIO EARTH
//
//  Centralised haptic feedback so every interaction surface (map taps,
//  module switches, automation confirmations, threshold crossings) fires
//  the same calibrated impulse. One call site per context; no scattered
//  UIFeedbackGenerator instances.
//

#if os(iOS)
import UIKit

public enum HapticEngine {
    public static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    public static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    public static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    public static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
#endif
