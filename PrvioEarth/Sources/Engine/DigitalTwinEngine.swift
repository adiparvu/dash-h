//
//  DigitalTwinEngine.swift
//  PRVIO EARTH
//
//  The heart of PRVIO EARTH. The Digital Twin Engine is the single,
//  observable source of truth for every entity on the property. Views
//  observe it; sensors, AI and automations mutate it. It is an
//  @Observable actor-friendly store that streams live telemetry into the
//  twin so the map always feels alive.
//

import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
public final class DigitalTwinEngine {

    /// Every physical thing on the property.
    public private(set) var entities: [PropertyEntity] = []

    /// Live AI insights derived from the current twin state.
    public private(set) var insights: [PrvioInsight] = []

    /// Automations (Node-RED inspired flows) acting on the twin.
    public private(set) var automations: [Automation] = []

    /// Chronological log of automation trigger fires (capped at 50 entries).
    public private(set) var automationFiredEvents: [AutomationFiredEvent] = []

    /// The property's geographic anchor (map centers here on launch).
    public let anchor: GeoPoint

    private let ai: AIEngine
    private var tickTask: Task<Void, Never>?
    private var tickCount = 0
    private var lastCriticalTitles: Set<String> = []

    public init(anchor: GeoPoint, seed: [PropertyEntity], automations: [Automation], ai: AIEngine = AIEngine()) {
        self.anchor = anchor
        self.entities = seed
        self.automations = automations
        self.ai = ai
        recomputeInsights()
        SpotlightBridge.index(seed)
    }

    // MARK: - Queries

    public func entities(in module: PropertyModule) -> [PropertyEntity] {
        guard module != .map else { return entities }
        return entities.filter { $0.kind.module == module }
    }

    public func entity(_ id: UUID) -> PropertyEntity? {
        entities.first { $0.id == id }
    }

    public func insights(for module: PropertyModule) -> [PrvioInsight] {
        module == .map ? insights : insights.filter { $0.module == module }
    }

    /// Aggregate health across a module — drives the dashboard rings.
    public func averageHealth(for module: PropertyModule) -> Double {
        let pool = entities(in: module)
        guard !pool.isEmpty else { return 1 }
        return pool.map(\.health.score).reduce(0, +) / Double(pool.count)
    }

    // MARK: - Mutation

    public func update(_ entity: PropertyEntity) {
        guard let idx = entities.firstIndex(where: { $0.id == entity.id }) else { return }
        entities[idx] = entity
        recomputeInsights()
    }

    public func addEntity(_ entity: PropertyEntity) {
        entities.append(entity)
        recomputeInsights()
        SpotlightBridge.index(entities)
    }

    public func removeEntity(_ id: UUID) {
        SpotlightBridge.deindex([id])
        entities.removeAll { $0.id == id }
        recomputeInsights()
    }

    public func toggleAutomation(_ id: UUID) {
        guard let idx = automations.firstIndex(where: { $0.id == id }) else { return }
        automations[idx].isEnabled.toggle()
    }

    public func addAutomation(_ automation: Automation) {
        automations.append(automation)
    }

    /// Apply a single telemetry frame from SensorGateway (Matter, HomeKit, MQTT, …)
    /// into the live twin. Skips unknown entity IDs silently.
    public func applyTelemetry(_ frame: TelemetryFrame) {
        guard let idx = entities.firstIndex(where: { $0.id == frame.entityID }) else { return }
        for (key, value) in frame.metrics {
            entities[idx].metrics[key] = value
        }
        if let health = frame.health {
            entities[idx].health.score = min(1, max(0, health))
        }
        entities[idx].lastUpdated = frame.timestamp
    }

    /// Apply a set of mutations to multiple entities in one pass — avoids
    /// triggering repeated `recomputeInsights` when wiring in external sensors.
    public func batchUpdate(_ updates: [(id: UUID, transform: (inout PropertyEntity) -> Void)]) {
        for update in updates {
            guard let idx = entities.firstIndex(where: { $0.id == update.id }) else { continue }
            update.transform(&entities[idx])
        }
    }

    // MARK: - Live Telemetry

    /// Begin streaming simulated sensor updates into the twin. In production
    /// this is replaced by the SensorGateway (MQTT/Matter/Thread bridge).
    public func startLiveTelemetry(interval: Duration = .seconds(3)) {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                self?.tick()
            }
        }
    }

    public func stopLiveTelemetry() { tickTask?.cancel() }

    private func tick() {
        for i in entities.indices {
            entities[i].apply(jitter: 0.04)
            entities[i].lastUpdated = .now
        }
        tickCount += 1
        // Throttle the expensive AI + snapshot write to every 3rd tick;
        // health-score drift is still applied on every tick so the map feels live.
        guard tickCount % 3 == 0 else { return }
        recomputeInsights()
        evaluateAutomations()
    }

    // MARK: - Intelligence

    private func recomputeInsights() {
        insights = ai.deriveInsights(from: entities)
        let newCriticalTitles = Set(insights.filter { $0.severity == .critical }.map(\.title))
        let addedCriticals = newCriticalTitles.subtracting(lastCriticalTitles)
        if !addedCriticals.isEmpty {
            #if os(iOS)
            HapticEngine.error()
            #endif
        }
        lastCriticalTitles = newCriticalTitles
        pushSnapshot()
    }

    private func pushSnapshot() {
        let total = entities.isEmpty ? 1.0 : entities.map(\.health.score).reduce(0, +) / Double(entities.count)
        let energy = entities.compactMap { $0.metrics["energyKwh"] }.reduce(0, +)

        var modHealth: [String: Double] = [:]
        for mod in PropertyModule.allCases where mod != .map && mod != .intelligence {
            modHealth[mod.rawValue] = averageHealth(for: mod)
        }

        let snap = TwinSnapshot(
            propertyHealth: total,
            alerts: insights.filter { $0.severity == .critical }.count,
            topInsight: insights.first?.title ?? "All systems healthy",
            energyKwh: energy,
            moduleHealth: modHealth)
        TwinSnapshotBridge.save(snap)
    }

    // MARK: - Automation trigger evaluation

    private func evaluateAutomations() {
        let now = Date.now
        for automation in automations where automation.isEnabled {
            // Rate-limit to prevent the same automation flooding the log (60 s minimum gap)
            if let last = automationFiredEvents.last(where: { $0.automationID == automation.id }),
               now.timeIntervalSince(last.firedAt) < 60 { continue }

            guard let trigger = automation.nodes.first(where: { $0.role == .trigger }),
                  isTriggerMet(trigger, for: automation) else { continue }

            let event = AutomationFiredEvent(
                automationID: automation.id,
                automationName: automation.name,
                module: automation.module,
                triggerTitle: trigger.title)
            automationFiredEvents.append(event)
            if automationFiredEvents.count > 50 { automationFiredEvents.removeFirst() }
            #if os(iOS)
            HapticEngine.impact(.heavy)
            #endif

            // Start a Live Activity for irrigation automations so the owner
            // can track the cycle from the Lock Screen and Dynamic Island.
            let cfg = trigger.config.lowercased()
            if cfg.contains("moisture") || cfg.contains("orchard") || cfg.contains("soil") {
                LiveActivityEngine.shared.startIrrigation(
                    automation: automation.name,
                    zone: automation.module.rawValue.capitalized,
                    durationMinutes: 30)
            }
        }
    }

    private func isTriggerMet(_ trigger: Automation.Node, for automation: Automation) -> Bool {
        let cfg = trigger.config.lowercased()

        if cfg.contains("oxygen") || cfg.contains("pond.oxygen") {
            return entities.contains { e in
                if case .pond(let p) = e.detail { return p.dissolvedOxygenMgL < 5 }
                return false
            }
        }
        if cfg.contains("moisture") || cfg.contains("soil") {
            return entities.contains { e in
                if case .garden(let g) = e.detail { return g.soilMoisture < 0.35 }
                return false
            }
        }
        if cfg.contains("orchard") {
            return entities.contains { e in
                if case .orchard(let o) = e.detail { return !o.irrigationActive }
                return false
            }
        }
        if cfg.contains("co2") {
            return entities.contains { e in
                if case .greenhouse(let g) = e.detail { return g.co2Ppm > 1200 }
                return false
            }
        }
        if cfg.contains("tree.pest") {
            return entities.contains { e in
                if case .tree(let t) = e.detail { return t.pestDetected }
                return false
            }
        }
        // Fallback: fire if any entity in the automation's module is stressed or critical
        return entities.filter { $0.kind.module == automation.module }
                       .contains { $0.health.score < 0.55 }
    }
}

// MARK: - Telemetry jitter helper

private extension PropertyEntity {
    /// Nudge metrics to simulate live sensor drift and occasionally affect
    /// health so the twin visibly breathes.
    mutating func apply(jitter: Double) {
        for key in metrics.keys {
            let delta = Double.random(in: -jitter...jitter)
            metrics[key, default: 0] *= (1 + delta)
        }
        let drift = Double.random(in: -0.01...0.012)
        health.score = min(1, max(0, health.score + drift))
    }
}
