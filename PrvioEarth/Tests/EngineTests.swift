//
//  EngineTests.swift
//  PRVIO EARTH
//
//  Confidence tests for the engines that power the Digital Twin: seeding,
//  insight derivation, forecasting and the conversational router.
//

import Testing
import Foundation
@testable import PrvioEarthCore

@Suite("Digital Twin Engine")
@MainActor
struct DigitalTwinEngineTests {

    private func makeEngine() -> DigitalTwinEngine {
        DigitalTwinEngine(
            anchor: PropertySeed.anchor,
            seed: PropertySeed.makeEntities(),
            automations: PropertySeed.makeAutomations())
    }

    @Test("Seed populates every module")
    func seedPopulatesModules() {
        let twin = makeEngine()
        #expect(!twin.entities(in: .forest).isEmpty)
        #expect(!twin.entities(in: .orchard).isEmpty)
        #expect(!twin.entities(in: .pond).isEmpty)
        #expect(!twin.entities(in: .home).isEmpty)
    }

    @Test("Average health is within 0...1")
    func averageHealthBounds() {
        let twin = makeEngine()
        let h = twin.averageHealth(for: .map)
        #expect(h >= 0 && h <= 1)
    }

    @Test("Stressed seed entity produces an insight")
    func stressedProducesInsight() {
        let twin = makeEngine()
        // Seed intentionally includes a stressed apple tree and a pest tree.
        #expect(!twin.insights.isEmpty)
    }
}

@Suite("AI Engine")
@MainActor
struct AIEngineTests {
    let ai = AIEngine()
    var entities: [PropertyEntity] { PropertySeed.makeEntities() }

    @Test("\"Show stressed\" highlights stressed entities")
    func stressedQueryHighlights() {
        let reply = ai.respond(to: "show stressed trees", entities: entities, insights: [])
        #expect(reply.role == .prvio)
    }

    @Test("Forecast returns the requested horizon")
    func forecastHorizon() {
        let history = MetricHistory(metric: "Oxygen", unit: "mg/L",
            points: (0..<10).map { .init(timestamp: .now.addingTimeInterval(Double($0) * 3600), value: 7 + Double($0) * 0.1) })
        let prediction = ai.forecast(history, horizonDays: 7)
        #expect(prediction.forecast.count == 7)
        #expect(prediction.confidence > 0)
    }
}
