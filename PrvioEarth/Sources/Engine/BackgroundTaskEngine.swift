//
//  BackgroundTaskEngine.swift
//  PRVIO EARTH
//
//  BGAppRefreshTask + BGProcessingTask integration so the twin snapshot,
//  Spotlight index and critical notifications stay fresh even when the app
//  is suspended. In production the two task identifiers must appear in
//  BGTaskSchedulerPermittedIdentifiers inside Info.plist; without them
//  the system silently ignores registration but the app still runs.
//

import Foundation

#if os(iOS)
import BackgroundTasks

@MainActor
public final class BackgroundTaskEngine {
    public static let shared = BackgroundTaskEngine()
    private init() {}

    // Must match Info.plist BGTaskSchedulerPermittedIdentifiers
    public static let appRefreshID = "com.prvio.earth.background-refresh"
    public static let processingID = "com.prvio.earth.processing"

    // MARK: - Registration

    /// Register BGTask handlers. Must be called before the first runloop cycle
    /// (e.g. from App.init()). Marked nonisolated so it is callable from any context.
    public nonisolated static func registerHandlers() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appRefreshID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false); return
            }
            Task { @MainActor in
                await BackgroundTaskEngine.shared.handleAppRefresh(task: refreshTask)
            }
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: processingID, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false); return
            }
            Task { @MainActor in
                await BackgroundTaskEngine.shared.handleProcessing(task: processingTask)
            }
        }
    }

    // MARK: - Scheduling

    public func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.appRefreshID)
        request.earliestBeginDate = .now.addingTimeInterval(15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    public func scheduleProcessing() {
        let request = BGProcessingTaskRequest(identifier: Self.processingID)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = .now.addingTimeInterval(60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    public func cancelAll() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
    }

    // MARK: - Handlers

    private func handleAppRefresh(task: BGAppRefreshTask) async {
        // Re-queue immediately so there is always a next scheduled run.
        scheduleAppRefresh()

        task.expirationHandler = { task.setTaskCompleted(success: false) }

        let entities = PersistenceStore.shared.loadEntities() ?? []
        let insights = AIEngine().deriveInsights(from: entities)

        // Push critical/warning notifications derived from the live twin.
        NotificationEngine.shared.schedule(insights)

        // Rebuild Spotlight index so entities remain discoverable.
        SpotlightBridge.index(entities)

        // Refresh the App Group snapshot consumed by widgets and the Watch.
        TwinSnapshotBridge.save(makeSnapshot(entities: entities, insights: insights))

        task.setTaskCompleted(success: true)
    }

    private func handleProcessing(task: BGProcessingTask) async {
        scheduleProcessing()

        task.expirationHandler = { task.setTaskCompleted(success: false) }

        // Same work as the lightweight refresh, but we can afford deeper analysis.
        let entities = PersistenceStore.shared.loadEntities() ?? []
        let insights = AIEngine().deriveInsights(from: entities)

        NotificationEngine.shared.schedule(insights)
        SpotlightBridge.index(entities)
        TwinSnapshotBridge.save(makeSnapshot(entities: entities, insights: insights))

        task.setTaskCompleted(success: true)
    }

    // MARK: - Snapshot builder

    private func makeSnapshot(entities: [PropertyEntity], insights: [PrvioInsight]) -> TwinSnapshot {
        let avgHealth = entities.isEmpty
            ? 1.0
            : entities.map(\.health.score).reduce(0, +) / Double(entities.count)
        let alerts = insights.filter { $0.severity >= .warning }.count
        let topInsight = insights.first?.title ?? "Property healthy"
        let energyKwh = PropertyAnalytics.energy(entities).todayKwh

        var moduleScores: [String: [Double]] = [:]
        for entity in entities {
            moduleScores[entity.kind.module.rawValue, default: []].append(entity.health.score)
        }
        let moduleHealth = moduleScores.mapValues { $0.reduce(0, +) / Double($0.count) }

        return TwinSnapshot(propertyHealth: avgHealth, alerts: alerts,
                            topInsight: topInsight, energyKwh: energyKwh,
                            moduleHealth: moduleHealth)
    }
}

#else

@MainActor
public final class BackgroundTaskEngine {
    public static let shared = BackgroundTaskEngine()
    private init() {}
    public nonisolated static func registerHandlers() {}
    public func scheduleAppRefresh() {}
    public func scheduleProcessing() {}
    public func cancelAll() {}
}

#endif
