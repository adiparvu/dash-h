//
//  LiveActivityEngine.swift
//  PRVIO EARTH
//
//  Manages the lifecycle of ActivityKit Live Activities for time-bounded
//  property events: irrigation cycles, pond treatments, harvest windows.
//  Only active on iOS — visionOS stub keeps the module graph intact.
//

import Foundation

#if os(iOS)
import ActivityKit

@MainActor
public final class LiveActivityEngine {
    public static let shared = LiveActivityEngine()
    private init() {}

    private var irrigationActivity: Activity<IrrigationAttributes>?
    private var currentZone: String = ""
    private var currentEndDate: Date = .now

    // MARK: - Irrigation

    public func startIrrigation(automation: String, zone: String, durationMinutes: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        currentZone = zone
        currentEndDate = .now.addingTimeInterval(Double(durationMinutes * 60))

        let state = IrrigationAttributes.ContentState(
            zone: zone, progress: 0, litersDelivered: 0, endsAt: currentEndDate)
        let attrs = IrrigationAttributes(automationName: automation)
        irrigationActivity = try? Activity.request(
            attributes: attrs,
            content: ActivityContent(state: state, staleDate: currentEndDate))
    }

    public func updateIrrigation(progress: Double, litersDelivered: Double) async {
        let state = IrrigationAttributes.ContentState(
            zone: currentZone, progress: progress,
            litersDelivered: litersDelivered, endsAt: currentEndDate)
        await irrigationActivity?.update(ActivityContent(state: state, staleDate: currentEndDate))
    }

    public func endIrrigation() async {
        let finalState = IrrigationAttributes.ContentState(
            zone: currentZone, progress: 1, litersDelivered: 0, endsAt: .now)
        await irrigationActivity?.end(
            ActivityContent(state: finalState, staleDate: .now),
            dismissalPolicy: .after(.now.addingTimeInterval(5)))
        irrigationActivity = nil
    }
}

#else

@MainActor
public final class LiveActivityEngine {
    public static let shared = LiveActivityEngine()
    private init() {}
    public func startIrrigation(automation: String, zone: String, durationMinutes: Int) {}
    public func updateIrrigation(progress: Double, litersDelivered: Double) async {}
    public func endIrrigation() async {}
}

#endif
