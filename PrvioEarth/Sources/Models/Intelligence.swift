//
//  Intelligence.swift
//  PRVIO EARTH
//
//  Models for the PRVIO Intelligence layer: insights, anomalies,
//  predictions and the conversational assistant. These are produced by
//  the AIEngine and surfaced across the map, detail sheets and the
//  assistant screen.
//

import Foundation

// MARK: - Insight

public struct PrvioInsight: Identifiable, Hashable, Sendable {
    public enum Severity: Int, Comparable, Sendable {
        case info, advisory, warning, critical
        public static func < (l: Severity, r: Severity) -> Bool { l.rawValue < r.rawValue }
        public var symbol: String {
            switch self {
            case .info: return "info.circle.fill"
            case .advisory: return "lightbulb.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "exclamationmark.octagon.fill"
            }
        }
    }

    public let id: UUID
    public var title: String
    public var detail: String
    public var severity: Severity
    public var module: PropertyModule
    public var relatedEntityIDs: [UUID]
    public var recommendation: String?
    public var createdAt: Date

    public init(id: UUID = UUID(), title: String, detail: String, severity: Severity,
                module: PropertyModule, relatedEntityIDs: [UUID] = [], recommendation: String? = nil,
                createdAt: Date = .now) {
        self.id = id; self.title = title; self.detail = detail; self.severity = severity
        self.module = module; self.relatedEntityIDs = relatedEntityIDs
        self.recommendation = recommendation; self.createdAt = createdAt
    }
}

// MARK: - Prediction

public struct Prediction: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var horizon: String              // e.g. "Next 7 days"
    public var confidence: Double            // 0...1
    public var forecast: [TimeSeriesPoint]
    public var summary: String

    public init(id: UUID = UUID(), title: String, horizon: String, confidence: Double,
                forecast: [TimeSeriesPoint], summary: String) {
        self.id = id; self.title = title; self.horizon = horizon
        self.confidence = confidence; self.forecast = forecast; self.summary = summary
    }
}

// MARK: - Assistant Conversation

public struct AssistantMessage: Identifiable, Hashable, Sendable {
    public enum Role: Sendable { case user, prvio }
    public let id = UUID()
    public var role: Role
    public var text: String
    public var insights: [PrvioInsight]
    public var highlightedEntityIDs: [UUID]

    public init(role: Role, text: String, insights: [PrvioInsight] = [], highlightedEntityIDs: [UUID] = []) {
        self.role = role; self.text = text
        self.insights = insights; self.highlightedEntityIDs = highlightedEntityIDs
    }
}

// MARK: - Automation (Node-RED inspired)

/// A visual, trigger→condition→action automation. Mirrors the Node-RED
/// flow model but expressed natively so PRVIO Intelligence can generate
/// automations from natural language ("Create irrigation automation").
public struct Automation: Identifiable, Hashable, Sendable {
    public struct Node: Hashable, Sendable {
        public enum Role: String, Sendable { case trigger, condition, action }
        public var role: Role
        public var title: String
        public var config: String
        public init(role: Role, title: String, config: String) {
            self.role = role; self.title = title; self.config = config
        }
    }

    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var nodes: [Node]
    public var module: PropertyModule

    public init(id: UUID = UUID(), name: String, isEnabled: Bool = true, nodes: [Node], module: PropertyModule) {
        self.id = id; self.name = name; self.isEnabled = isEnabled
        self.nodes = nodes; self.module = module
    }
}

// MARK: - Automation fired event

/// Recorded each time a live trigger condition is met, powering the
/// AutomationStudio activity feed and the PRVIO Intelligence context.
public struct AutomationFiredEvent: Identifiable, Sendable {
    public let id = UUID()
    public var automationID: UUID
    public var automationName: String
    public var module: PropertyModule
    public var triggerTitle: String
    public var firedAt: Date

    public init(automationID: UUID, automationName: String, module: PropertyModule,
                triggerTitle: String, firedAt: Date = .now) {
        self.automationID = automationID
        self.automationName = automationName
        self.module = module
        self.triggerTitle = triggerTitle
        self.firedAt = firedAt
    }
}
