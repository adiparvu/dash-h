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
#if canImport(FoundationModels)
import FoundationModels
#endif

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
            case .garden(let g) where g.soilMoisture < 0.35:
                out.append(PrvioInsight(
                    title: "Low moisture in \(e.name)",
                    detail: "Soil moisture at \(Int(g.soilMoisture * 100))% — below the 35% threshold.",
                    severity: .warning, module: .garden, relatedEntityIDs: [e.id],
                    recommendation: "Run drip irrigation for 15 minutes."))
            case .greenhouse(let g) where g.temperatureC > 35:
                out.append(PrvioInsight(
                    title: "Heat stress in \(e.name)",
                    detail: "Temperature at \(String(format: "%.1f", g.temperatureC))°C — above safe limit.",
                    severity: .critical, module: .greenhouse, relatedEntityIDs: [e.id],
                    recommendation: "Open vents and reduce grow-light intensity."))
            case .greenhouse(let g) where g.co2Ppm > 1500:
                out.append(PrvioInsight(
                    title: "CO₂ spike in \(e.name)",
                    detail: "CO₂ at \(Int(g.co2Ppm)) ppm — ventilation needed.",
                    severity: .warning, module: .greenhouse, relatedEntityIDs: [e.id],
                    recommendation: "Increase ventilation for 30 minutes."))
            case .agriculture(let a) where a.soilMoisture < 0.30:
                out.append(PrvioInsight(
                    title: "\(e.name) drought stress",
                    detail: "Soil moisture at \(Int(a.soilMoisture * 100))% — \(a.cropType) needs water.",
                    severity: .warning, module: .agriculture, relatedEntityIDs: [e.id],
                    recommendation: "Activate pivot irrigator for \(a.cropType) fields."))
            case .agriculture(let a) where a.npk.nitrogen < 60:
                out.append(PrvioInsight(
                    title: "N-deficiency in \(e.name)",
                    detail: "Nitrogen at \(Int(a.npk.nitrogen)) kg/ha — below optimal for \(a.growthStage.rawValue) stage.",
                    severity: .advisory, module: .agriculture, relatedEntityIDs: [e.id],
                    recommendation: "Schedule top-dressing application within 5 days."))
            default: break
            }
        }

        return out.sorted { $0.severity > $1.severity }
    }

    // MARK: - Weather-contextual insights

    /// Translate live weather conditions and the short-range forecast into
    /// actionable twin insights. Called alongside `deriveInsights` so weather
    /// hazards surface alongside entity-level anomalies in the same feed.
    public func deriveWeatherInsights(
        current: WeatherEngine.Current?,
        forecast: [WeatherEngine.DayForecast],
        entities: [PropertyEntity]
    ) -> [PrvioInsight] {
        var out: [PrvioInsight] = []

        // Frost risk — tomorrow's low threatens frost-sensitive modules
        if let low = forecast.first?.lowC, low < 2 {
            let targets = entities.filter { [.orchard, .garden, .greenhouse].contains($0.kind.module) }
            if !targets.isEmpty {
                out.append(PrvioInsight(
                    title: "Frost risk overnight — \(String(format: "%.1f", low))°C low",
                    detail: "Tomorrow's low of \(String(format: "%.1f", low))°C may damage frost-sensitive crops.",
                    severity: low < 0 ? .critical : .warning,
                    module: .garden,
                    relatedEntityIDs: targets.map(\.id),
                    recommendation: "Cover exposed plants and pre-heat the greenhouse before nightfall."))
            }
        }

        // Heat wave — extreme high temp stresses outdoor modules
        if let high = forecast.first?.highC, high > 34 {
            let targets = entities.filter { [.agriculture, .orchard, .garden].contains($0.kind.module) }
            out.append(PrvioInsight(
                title: "Heat wave: \(String(format: "%.0f", high))°C forecast",
                detail: "Extreme heat may stress outdoor crops and reduce yield quality.",
                severity: .warning,
                module: .agriculture,
                relatedEntityIDs: targets.map(\.id),
                recommendation: "Irrigate early morning and apply mulch to retain soil moisture."))
        }

        // Drought outlook — 2 of next 3 days below 10 % precip probability
        let droughtDays = forecast.prefix(3).filter { $0.precipProbability < 0.10 }.count
        if droughtDays >= 2 {
            let soilEntities = entities.filter { e in
                switch e.detail {
                case .agriculture, .orchard, .garden: return true
                default: return false
                }
            }
            if !soilEntities.isEmpty {
                out.append(PrvioInsight(
                    title: "Dry spell ahead — plan irrigation",
                    detail: "Less than 10% rain probability over the next 3 days.",
                    severity: .advisory,
                    module: .agriculture,
                    relatedEntityIDs: soilEntities.map(\.id),
                    recommendation: "Increase irrigation frequency and check soil moisture sensors daily."))
            }
        }

        // High wind — structural hazard for orchard and greenhouse
        if let windKph = current?.windKph, windKph > 50 {
            let targets = entities.filter { [.orchard, .greenhouse].contains($0.kind.module) }
            if !targets.isEmpty {
                out.append(PrvioInsight(
                    title: "High wind: \(Int(windKph)) km/h",
                    detail: "Strong winds may damage orchard canopies and greenhouse structures.",
                    severity: .warning,
                    module: .orchard,
                    relatedEntityIDs: targets.map(\.id),
                    recommendation: "Secure support netting and close greenhouse vents."))
            }
        }

        // Heavy rain — surface runoff risk to pond chemistry
        if let tomorrow = forecast.first, tomorrow.precipProbability > 0.85 {
            let ponds = entities.filter { if case .pond = $0.detail { return true }; return false }
            if !ponds.isEmpty {
                out.append(PrvioInsight(
                    title: "Heavy rain may affect pond chemistry",
                    detail: "High precipitation probability (\(Int(tomorrow.precipProbability * 100))%) — runoff could shift pH and oxygen levels.",
                    severity: .advisory,
                    module: .pond,
                    relatedEntityIDs: ponds.map(\.id),
                    recommendation: "Monitor pond parameters after rainfall and adjust aeration if needed."))
            }
        }

        return out
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
    public func respond(
        to query: String,
        entities: [PropertyEntity],
        insights: [PrvioInsight],
        weather: WeatherEngine.Current? = nil,
        forecast: [WeatherEngine.DayForecast] = []
    ) -> AssistantMessage {
        let q = query.lowercased()

        // Weather-contextual queries — resolved before domain-specific ones
        if q.contains("frost") || q.contains("freeze") || q.contains("cold tonight") {
            if let low = forecast.first?.lowC {
                let risk = low < 0 ? "hard freeze expected" : low < 2 ? "frost risk" : "no frost risk tonight"
                let advice = low < 2
                    ? " Protect frost-sensitive plants and pre-heat the greenhouse before nightfall."
                    : " All outdoor modules should be fine overnight."
                return AssistantMessage(role: .prvio,
                    text: "Tonight's forecast low is \(String(format: "%.1f", low))°C — \(risk).\(advice)")
            }
        }

        if q.contains("rain") || (q.contains("irrigat") && q.contains("today")) || q.contains("should i water") {
            if let tomorrow = forecast.first {
                let pct = Int(tomorrow.precipProbability * 100)
                let soilLow = entities.contains { e in
                    switch e.detail {
                    case .garden(let g): return g.soilMoisture < 0.45
                    case .agriculture(let a): return a.soilMoisture < 0.40
                    default: return false
                    }
                }
                if tomorrow.precipProbability > 0.6 {
                    return AssistantMessage(role: .prvio,
                        text: "Rain is likely tomorrow (\(pct)% probability) — hold off on irrigation and let the forecast do the work.")
                } else {
                    return AssistantMessage(role: .prvio,
                        text: "Only \(pct)% rain chance tomorrow. \(soilLow ? "Soil moisture is trending low — run irrigation tonight before the dry spell." : "Moisture levels look good for now.")")
                }
            }
        }

        if (q.contains("weather") || q.contains("forecast")) && !q.contains("pond") && !q.contains("greenhouse") {
            if let wx = weather {
                let days = forecast.prefix(3).map { "\(Int($0.highC))°/\(Int($0.lowC))°" }.joined(separator: ", ")
                return AssistantMessage(role: .prvio,
                    text: "Current: \(wx.condition), \(Int(wx.tempC))°C, wind \(Int(wx.windKph)) km/h, UV \(wx.uvIndex). 3-day: \(days).")
            } else if let tomorrow = forecast.first {
                return AssistantMessage(role: .prvio,
                    text: "Tomorrow: \(Int(tomorrow.highC))°C high / \(Int(tomorrow.lowC))°C low, \(Int(tomorrow.precipProbability * 100))% rain probability.")
            }
        }

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

        if q.contains("energy") || q.contains("solar") || q.contains("power") {
            let panels = entities.filter { $0.kind == .solarPanel }
            let totalW = panels.compactMap { $0.metrics["powerW"] }.reduce(0, +)
            return AssistantMessage(role: .prvio,
                text: totalW > 0
                    ? "Your \(panels.count) solar panel\(panels.count == 1 ? "" : "s") are generating \(String(format: "%.0f", totalW)) W right now — enough to cover your current load."
                    : "Solar generation is low right now. Check for shading or schedule a panel inspection.",
                highlightedEntityIDs: panels.map(\.id))
        }

        if q.contains("carbon") || (q.contains("forest") && !q.contains("stress")) {
            let trees = entities.filter { if case .tree = $0.detail { return true }; return false }
            let totalC = trees.compactMap { $0.metrics["carbonKg"] }.reduce(0, +)
            return AssistantMessage(role: .prvio,
                text: "Your \(trees.count) trees are sequestering an estimated \(String(format: "%.0f", totalC)) kg CO₂ equivalent. Healthy canopy density is your most effective long-term carbon sink.",
                highlightedEntityIDs: trees.map(\.id))
        }

        if q.contains("harvest") || (q.contains("orchard") && !q.contains("irrigation")) {
            let orchards = entities.filter { if case .orchard = $0.detail { return true }; return false }
            let ready = orchards.filter { e -> Bool in
                if case .orchard(let o) = e.detail { return o.phenophase == .ripening || o.phenophase == .harvest }
                return false
            }
            return AssistantMessage(role: .prvio,
                text: ready.isEmpty
                    ? "No orchard sections are harvest-ready yet. I'll alert you when phenophase reaches ripening."
                    : "\(ready.count) orchard section\(ready.count == 1 ? "" : "s") \(ready.count == 1 ? "is" : "are") at ripening or harvest stage. Consider scheduling the picking crew this week.",
                highlightedEntityIDs: ready.map { $0.id })
        }

        if q.contains("offline") || (q.contains("device") && (q.contains("down") || q.contains("fail"))) {
            let offline = entities.filter { e -> Bool in
                if case .device(let d) = e.detail { return !d.isOnline }
                return false
            }
            return AssistantMessage(role: .prvio,
                text: offline.isEmpty
                    ? "All devices are online — no connectivity issues detected across the property."
                    : "\(offline.count) device\(offline.count == 1 ? " is" : "s are") offline. Check power and network connectivity for these nodes.",
                insights: insights.filter { $0.module == .home && $0.severity >= .advisory },
                highlightedEntityIDs: offline.map { $0.id })
        }

        if q.contains("greenhouse") || (q.contains("co2") && !q.contains("pond")) || (q.contains("temperature") && !q.contains("pond")) {
            let greenhouses = entities.filter { $0.kind.module == .greenhouse }
            let hot = greenhouses.filter { e -> Bool in
                if case .greenhouse(let g) = e.detail { return g.temperatureC > 30 }
                return false
            }
            return AssistantMessage(role: .prvio,
                text: hot.isEmpty
                    ? "Greenhouse climate is within target — temperature, CO₂ and humidity all look good."
                    : "\(hot.count) greenhouse\(hot.count == 1 ? "" : "s") running above 30°C. Open vents and shade if temperature exceeds 35°C.",
                insights: insights.filter { $0.module == .greenhouse },
                highlightedEntityIDs: greenhouses.map { $0.id })
        }

        if q.contains("nitrogen") || q.contains("fertiliz") || q.contains("npk") || q.contains("field") {
            let fields = entities.filter { if case .agriculture = $0.detail { return true }; return false }
            let lowN = fields.filter { e -> Bool in
                if case .agriculture(let a) = e.detail { return a.npk.nitrogen < 60 }
                return false
            }
            return AssistantMessage(role: .prvio,
                text: lowN.isEmpty
                    ? "Field nutrient levels are within target range. Continue regular soil monitoring."
                    : "\(lowN.count) field\(lowN.count == 1 ? "" : "s") show nitrogen below 60 kg/ha. Schedule top-dressing within 5 days for optimal yield.",
                highlightedEntityIDs: lowN.map(\.id))
        }

        if q.contains("pest") || (q.contains("camera") && !q.contains("offline")) || q.contains("detect") {
            let pestEntities = entities.filter { e -> Bool in
                if case .tree(let t) = e.detail { return t.pestDetected }
                return false
            }
            return AssistantMessage(role: .prvio,
                text: pestEntities.isEmpty
                    ? "No pest alerts from Camera AI right now — all clear across the property."
                    : "Camera AI has flagged \(pestEntities.count) tree\(pestEntities.count == 1 ? "" : "s") with pest activity. Consider targeted treatment and monitoring spread.",
                insights: insights.filter { $0.module == .forest },
                highlightedEntityIDs: pestEntities.map { $0.id })
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

// MARK: - Apple Intelligence path

#if canImport(FoundationModels)
extension AIEngine {
    /// On-device Apple Intelligence response using Foundation Models.
    /// Feeds entity context as instructions so the model understands the twin
    /// without sending data off-device. Falls back to the rule engine on any
    /// error (model unavailable, unsupported hardware, inference timeout).
    @available(iOS 26, *)
    public func respondIntelligence(
        to query: String,
        entities: [PropertyEntity],
        insights: [PrvioInsight]
    ) async -> AssistantMessage {
        let stressed = entities.filter {
            $0.health.status == .stressed || $0.health.status == .critical
        }
        let insightLines = insights.prefix(3).map { "• \($0.title)" }.joined(separator: " ")
        let instructions = """
        You are PRVIO Intelligence, a private on-device property advisor for a digital twin \
        ecosystem. Answer in 1–2 sentences, concisely and helpfully. \
        Property context: \(entities.count) entities, \(stressed.count) currently stressed. \
        Recent insights: \(insightLines)
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: query)
            return AssistantMessage(role: .prvio, text: response.content)
        } catch {
            return respond(to: query, entities: entities, insights: insights)
        }
    }
}
#endif

private extension Optional where Wrapped == EntityDetail {
    var orchardSpecies: String? {
        if case .orchard(let p) = self { return p.species }
        return nil
    }
}
