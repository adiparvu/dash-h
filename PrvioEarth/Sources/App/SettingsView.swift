//
//  SettingsView.swift
//  PRVIO EARTH
//
//  User preferences: telemetry update interval, unit system, notification
//  thresholds and data management. All stored via @AppStorage so they
//  survive app restarts and are observable by any view that needs them.
//

import SwiftUI

public struct SettingsView: View {
    // Telemetry
    @AppStorage("telemetryIntervalSec") private var telemetryInterval: Double = 5.0
    // Units
    @AppStorage("useImperialUnits") private var useImperial: Bool = false
    // Notification thresholds
    @AppStorage("pondOxygenThreshold") private var pondOxygenThreshold: Double = 5.0
    @AppStorage("soilMoistureThreshold") private var soilMoistureThreshold: Double = 35.0
    @AppStorage("healthScoreThreshold") private var healthScoreThreshold: Double = 40.0
    // Notifications enabled
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    // Map style
    @AppStorage("mapSatelliteMode") private var mapSatelliteMode: Bool = true

    var onClearData: (() -> Void)?

    public init(onClearData: (() -> Void)? = nil) {
        self.onClearData = onClearData
    }

    @State private var showClearConfirm = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Settings").font(.prvioTitle())

                settingsGroup(title: "Display", icon: "map.fill", tint: .prvioHorizon) {
                    toggleRow(title: "Satellite map", subtitle: "Show high-resolution satellite imagery",
                              icon: "globe.americas.fill", isOn: $mapSatelliteMode, tint: .prvioHorizon)
                    toggleRow(title: "Imperial units", subtitle: "Use feet, °F and pounds instead of SI",
                              icon: "ruler.fill", isOn: $useImperial, tint: .prvioHorizon)
                }

                settingsGroup(title: "Telemetry", icon: "antenna.radiowaves.left.and.right", tint: .domainForest) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Update interval", systemImage: "clock").font(.prvioLabel())
                            Spacer()
                            Text(telemetryInterval == 1 ? "1 s" : "\(Int(telemetryInterval)) s")
                                .font(.prvioCaption()).foregroundStyle(.secondary)
                        }
                        Slider(value: $telemetryInterval, in: 1...30, step: 1)
                            .tint(.domainForest)
                    }
                    .padding(Spacing.md)
                    .liquidGlass(.raised, tint: .domainForest, interactive: false)
                }

                settingsGroup(title: "Notifications", icon: "bell.fill", tint: .domainOrchard) {
                    toggleRow(title: "Enable notifications", subtitle: "Critical and warning alerts",
                              icon: "bell.badge.fill", isOn: $notificationsEnabled, tint: .domainOrchard)

                    thresholdRow(title: "Pond O₂ alert", subtitle: "Alert when dissolved oxygen drops below",
                                 icon: "wind", value: $pondOxygenThreshold, range: 2...8,
                                 unit: "mg/L", tint: .domainWater)

                    thresholdRow(title: "Soil moisture alert", subtitle: "Alert when soil moisture drops below",
                                 icon: "humidity", value: $soilMoistureThreshold, range: 10...60,
                                 unit: "%", tint: .domainGarden)

                    thresholdRow(title: "Health score alert", subtitle: "Alert when health drops below",
                                 icon: "heart.fill", value: $healthScoreThreshold, range: 20...70,
                                 unit: "%", tint: .healthStressed)
                }

                settingsGroup(title: "Data", icon: "externaldrive.fill", tint: .domainSecurity) {
                    Button {
                        showClearConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill").foregroundStyle(.healthCritical).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear saved data").font(.prvioLabel()).foregroundStyle(.healthCritical)
                                Text("Removes cached twin state; reloads seed data on next launch")
                                    .font(.prvioCaption()).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(Spacing.md)
                        .liquidGlass(.raised, tint: .healthCritical, interactive: false)
                    }
                    .buttonStyle(.plain)
                }

                Text("PRVIO EARTH — Digital Twin Ecosystem\nVersion 1.0 · iOS 27")
                    .font(.prvioCaption())
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.sm)
            }
            .padding(Spacing.lg)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial).ignoresSafeArea()
        }
        .confirmationDialog("Clear all saved twin data?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear Data", role: .destructive) {
                PersistenceStore.shared.clear()
                onClearData?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Digital Twin will reload its default seed data on next launch. This cannot be undone.")
        }
    }

    private func settingsGroup<Content: View>(title: String, icon: String, tint: Color,
                                              @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(title, systemImage: icon).font(.prvioHeadline()).foregroundStyle(tint)
            content()
        }
    }

    private func toggleRow(title: String, subtitle: String, icon: String,
                            isOn: Binding<Bool>, tint: Color) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon).foregroundStyle(tint).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.prvioLabel())
                    Text(subtitle).font(.prvioCaption()).foregroundStyle(.secondary)
                }
            }
        }
        .tint(tint)
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: tint, interactive: false)
    }

    private func thresholdRow(title: String, subtitle: String, icon: String,
                               value: Binding<Double>, range: ClosedRange<Double>,
                               unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon).foregroundStyle(tint).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.prvioLabel())
                    Text(subtitle).font(.prvioCaption()).foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.0f \(unit)", value.wrappedValue))
                    .font(.prvioCaption()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1).tint(tint)
        }
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: tint, interactive: false)
    }
}
