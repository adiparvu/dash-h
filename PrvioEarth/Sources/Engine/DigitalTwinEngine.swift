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

    /// The property's geographic anchor (map centers here on launch).
    public let anchor: GeoPoint

    private let ai: AIEngine
    private var tickTask: Task<Void, Never>?

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
        recomputeInsights()
    }

    // MARK: - Intelligence

    private func recomputeInsights() {
        insights = ai.deriveInsights(from: entities)
        pushSnapshot()
    }

    private func pushSnapshot() {
        let total = entities.isEmpty ? 1.0 : entities.map(\.health.score).reduce(0, +) / Double(entities.count)
        let energy = entities.compactMap { $0.metrics["energyKwh"] }.reduce(0, +)
        let snap = TwinSnapshot(
            propertyHealth: total,
            alerts: insights.filter { $0.severity == .critical }.count,
            topInsight: insights.first?.title ?? "All systems healthy",
            energyKwh: energy)
        TwinSnapshotBridge.save(snap)
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
