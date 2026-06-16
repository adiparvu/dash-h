//
//  AIEngine.swift
//  PRVIO EARTH
//
//  PRVIO Intelligence — the reasoning layer. In production this is backed
//  by on-device Apple Intelligence (Foundation Models) for private,
//  low-latency inference, with optional cloud escalation for heavy
//  forecasting. Here it provides deterministic, rule-based reasoning that
//  produces the same shape of output the ML models will, so the entire UI
//  is buildable and testable today.
//

import Foundation

public struct AIEngine: Sendable {

    public init() {}

    // MARK: - Anomaly Detection → Insights

    /// Derive insights from the live twin. This mirrors the on-device
    /// anomaly-detection pipeline: per-entity rules + cross-entity patterns.
    public func deriveInsights(from entities: [PropertyEntity]) -> [PrvioInsight] {
        var out: [PrvioInsight] = []

        for e in entities {
            // Health-based anomalies
            if e.health.status == .critical {
                out.append(PrvioInsight(
                    title: "\(e.name) is in critical condition",
                    detail: "Health score dropped to \(Int(e.health.score * 100))%. Immediate inspection recommended.",
                    severity: .critical, module: e.kind.module,
                    relatedEntityIDs: [e.id],
                    recommendation: "Schedule an on-site inspection and review recent telemetry."))
            } else if e.health.status == .stressed {
                out.append(PrvioInsight(
                    title: "\(e.name) shows stress",
                    detail: "Trending below stable range. Monitor closely.",
                    severity: .warning, module: e.kind.module, relatedEntityIDs: [e.id]))
            }

            if e.health.diseaseRisk > 0.6 {
                out.append(PrvioInsight(
                    title: "Elevated disease risk: \(e.name)",
                    detail: "Disease risk at \(Int(e.health.diseaseRisk * 100))%.",
                    severity: .warning, module: e.kind.module, relatedEntityIDs: [e.id],
                    recommendation: "Apply preventative treatment and isolate if symptoms spread."))
            }

            // Module-specific reasoning
            switch e.detail {
            case .pond(let p):
                if p.dissolvedOxygenMgL < 5 {
                    out.append(PrvioInsight(
                        title: "Oxygen crash risk in \(e.name)",
                        detail: "Dissolved oxygen at \(String(format: "%.1f", p.dissolvedOxygenMgL)) mg/L — below safe threshold.",
                        severity: .critical, module: .pond, relatedEntityIDs: [e.id],
                        recommendation: "Activate aerators and reduce feeding."))
                }
                if p.ammoniaMgL > 0.5 {
                    out.append(PrvioInsight(
                        title: "Ammonia spike in \(e.name)",
                        detail: "Ammonia at \(String(format: "%.2f", p.ammoniaMgL)) mg/L.",
                        severity: .warning, module: .pond, relatedEntityIDs: [e.id],
                        recommendation: "Check biofilter and perform partial water change."))
                }
            case .tree(let t) where t.pestDetected:
                out.append(PrvioInsight(
                    title: "Pest detected near \(e.name)",
                    detail: "Camera AI flagged pest activity on \(t.species).",
                    severity: .warning, module: .forest, relatedEntityIDs: [e.id]))
            case .device(let d) where !d.isOnline:
                out.append(PrvioInsight(
                    title: "\(e.name) is offline",
                    detail: "Lost connection over \(d.protocolType.rawValue).",
                    severity: .advisory, module: .home, relatedEntityIDs: [e.id]))
            default: break
            }
        }

        return out.sorted { $0.severity > $1.severity }
    }

    // MARK: - Predictive Analytics

    /// Produce a forward forecast for a metric history using simple
    /// exponential smoothing — placeholder for the on-device timeseries
    /// model. Returns the same shape the ML forecaster will.
    public func forecast(_ history: MetricHistory, horizonDays: Int = 7) -> Prediction {
        let values = history.points.map(\.value)
        let alpha = 0.4
        var level = values.first ?? 0
        for v in values { level = alpha * v + (1 - alpha) * level }

        let trend = (values.last ?? level) - (values.first ?? level)
        let step = trend / Double(max(values.count, 1))

        var forecast: [TimeSeriesPoint] = []
        let start = Date.now
        for day in 1...horizonDays {
            let value = level + step * Double(day) + Double.random(in: -0.5...0.5)
            forecast.append(.init(timestamp: start.addingTimeInterval(Double(day) * 86_400), value: value))
        }

        return Prediction(
            title: "\(history.metric) forecast",
            horizon: "Next \(horizonDays) days",
            confidence: 0.78,
            forecast: forecast,
            summary: trend >= 0
                ? "\(history.metric) is trending upward and should remain within healthy range."
                : "\(history.metric) is declining — consider intervention this week.")
    }

    // MARK: - Conversational Assistant

    /// Resolve a natural-language query against the twin. A production build
    /// routes this through Apple Intelligence with the twin as tool-callable
    /// context; this rule-based router handles the canonical example queries.
    public func respond(to query: String, entities: [PropertyEntity], insights: [PrvioInsight]) -> AssistantMessage {
        let q = query.lowercased()

        if q.contains("stress") {
            let stressed = entities.filter { $0.health.status == .stressed || $0.health.status == .critical }
            return AssistantMessage(
                role: .prvio,
                text: stressed.isEmpty
                    ? "Good news — no stressed entities right now. Your property is healthy."
                    : "I found \(stressed.count) entities under stress. I've highlighted them on the map.",
                highlightedEntityIDs: stressed.map(\.id))
        }

        if q.contains("apple") && (q.contains("less") || q.contains("fruit")) {
            let apples = entities.filter { ($0.detail.orchardSpecies ?? "").lowercased().contains("apple") }
            return AssistantMessage(
                role: .prvio,
                text: "Your apple trees are yielding less due to lower soil moisture during flowering and a delayed pruning cycle. I recommend adjusting irrigation by +15% through the fruiting phase.",
                highlightedEntityIDs: apples.map(\.id))
        }

        if q.contains("pond") && q.contains("predict") {
            return AssistantMessage(
                role: .prvio,
                text: "Pond health should stay stable next week. Dissolved oxygen dips slightly midweek with warmer nights — I'll keep the aerators on the evening schedule.")
        }

        if q.contains("irrigation") && (q.contains("create") || q.contains("automation")) {
            return AssistantMessage(
                role: .prvio,
                text: "Drafted an irrigation automation: when orchard soil moisture < 35% AND no rain forecast, run drip valves for 20 minutes at dawn. Tap to review and enable.")
        }

        let topInsight = insights.first
        return AssistantMessage(
            role: .prvio,
            text: topInsight.map { "Here's what stands out: \($0.title). \($0.detail)" }
                ?? "Everything looks calm across your property right now. Ask me about trees, the pond, energy or harvest planning.",
            insights: Array(insights.prefix(3)),
            highlightedEntityIDs: topInsight?.relatedEntityIDs ?? [])
    }
}

private extension Optional where Wrapped == EntityDetail {
    var orchardSpecies: String? {
        if case .orchard(let p) = self { return p.species }
        return nil
    }
}
