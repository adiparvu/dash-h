//
//  PrvioAppIntents.swift
//  PRVIO EARTH
//
//  App Intents integration — Siri, Shortcuts and Spotlight. Three intents
//  surface the most-queried property states without opening the app. All
//  read from TwinSnapshotBridge (App Group) so they work even when the
//  Digital Twin Engine is not in memory.
//

import AppIntents
import Foundation

// MARK: - Module enum for Siri disambiguation

public enum PropertyModuleEntity: String, AppEnum {
    case forest, orchard, pond, garden, greenhouse, home, agriculture

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Property Module")
    public static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .forest:      "Forest",
        .orchard:     "Orchard",
        .pond:        "Pond",
        .garden:      "Garden",
        .greenhouse:  "Glass House",
        .home:        "Home",
        .agriculture: "Fields",
    ]
}

// MARK: - Property Health

public struct PropertyHealthIntent: AppIntent {
    public static let title: LocalizedStringResource = "Property Health"
    public static let description = IntentDescription(
        "Get the overall health score, active alerts and top insight for your Digital Twin.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let snap = TwinSnapshotBridge.load() ?? TwinSnapshot.placeholder
        let pct  = Int(snap.propertyHealth * 100)
        let aStr = snap.alerts == 1 ? "1 alert" : "\(snap.alerts) alerts"
        return .result(dialog: IntentDialog(
            "\(pct)% healthy, \(aStr). \(snap.topInsight)."))
    }
}

// MARK: - Module Summary

public struct ModuleSummaryIntent: AppIntent {
    public static let title: LocalizedStringResource = "Module Summary"
    public static let description = IntentDescription(
        "Ask PRVIO for the status of a specific property module.")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Module") public var module: PropertyModuleEntity

    public init() {}
    public init(module: PropertyModuleEntity) { self.module = module }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let snap  = TwinSnapshotBridge.load() ?? TwinSnapshot.placeholder
        let pct   = Int(snap.propertyHealth * 100)
        let label = PropertyModuleEntity.caseDisplayRepresentations[module]?.title.key ?? module.rawValue
        return .result(dialog: IntentDialog(
            "Your \(label) module is part of a property at \(pct)% overall health. \(snap.topInsight)."))
    }
}

// MARK: - Open Module (navigates to that module in the live twin)

public struct OpenModuleIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Module"
    public static let description = IntentDescription(
        "Open the Digital Twin and navigate directly to a specific property module.")
    public static var openAppWhenRun: Bool = true

    @Parameter(title: "Module") public var module: PropertyModuleEntity

    public init() {}
    public init(module: PropertyModuleEntity) { self.module = module }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let label = PropertyModuleEntity.caseDisplayRepresentations[module]?.title.key ?? module.rawValue
        return .result(dialog: IntentDialog("Opening \(label) on your Digital Twin."))
    }
}

// MARK: - Energy Status

public struct EnergyStatusIntent: AppIntent {
    public static let title: LocalizedStringResource = "Energy Status"
    public static let description = IntentDescription(
        "Get today's solar energy production for your property.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let snap = TwinSnapshotBridge.load() ?? TwinSnapshot.placeholder
        let kwh = String(format: "%.1f", snap.energyKwh)
        return .result(dialog: IntentDialog(
            "Your property has produced \(kwh) kWh today. Overall health is \(Int(snap.propertyHealth * 100))%."))
    }
}

// MARK: - Active Alerts

public struct AlertsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Active Alerts"
    public static let description = IntentDescription(
        "Get the number of active alerts and the top insight for your Digital Twin.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let snap = TwinSnapshotBridge.load() ?? TwinSnapshot.placeholder
        if snap.alerts == 0 {
            return .result(dialog: IntentDialog("No active alerts. \(snap.topInsight)."))
        }
        let aStr = snap.alerts == 1 ? "1 active alert" : "\(snap.alerts) active alerts"
        return .result(dialog: IntentDialog("\(aStr). Top insight: \(snap.topInsight)."))
    }
}

// MARK: - Shortcuts Provider

public struct PrvioShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PropertyHealthIntent(),
            phrases: [
                "Check my property health with \(.applicationName)",
                "How is my property doing in \(.applicationName)",
                "\(.applicationName) property status",
            ],
            shortTitle: "Property Health",
            systemImageName: "globe.americas.fill")

        AppShortcut(
            intent: ModuleSummaryIntent(),
            phrases: [
                "Check my \(\.$module) with \(.applicationName)",
                "\(.applicationName) show \(\.$module) status",
            ],
            shortTitle: "Module Status",
            systemImageName: "chart.bar.xaxis")

        AppShortcut(
            intent: OpenModuleIntent(),
            phrases: [
                "Open my \(\.$module) in \(.applicationName)",
                "\(.applicationName) navigate to \(\.$module)",
            ],
            shortTitle: "Open Module",
            systemImageName: "mappin.circle.fill")

        AppShortcut(
            intent: EnergyStatusIntent(),
            phrases: [
                "Energy status in \(.applicationName)",
                "How much energy has my property produced with \(.applicationName)",
            ],
            shortTitle: "Energy Status",
            systemImageName: "bolt.fill")

        AppShortcut(
            intent: AlertsIntent(),
            phrases: [
                "Any alerts on \(.applicationName)",
                "Check \(.applicationName) alerts",
            ],
            shortTitle: "Active Alerts",
            systemImageName: "bell.badge.fill")
    }
}
