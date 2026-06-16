//
//  AutomationStudioView.swift
//  PRVIO EARTH
//
//  Node-RED inspired visual automation studio, reimagined as Liquid Glass.
//  Automations are trigger → condition → action flows rendered as connected
//  glass nodes. PRVIO Intelligence can draft new flows from natural language;
//  the user reviews and enables them here.
//

import SwiftUI

@MainActor
@Observable
public final class AutomationStudioViewModel {
    public let twin: DigitalTwinEngine
    private let ai = AIEngine()
    public var draftPrompt: String = ""
    public var pendingDraft: Automation?

    public init(twin: DigitalTwinEngine) { self.twin = twin }

    public var automations: [Automation] { twin.automations }

    public func toggle(_ automation: Automation) { twin.toggleAutomation(automation.id) }

    /// Generate a flow from natural language (PRVIO Intelligence).
    public func generateDraft() {
        let p = draftPrompt.lowercased()
        let draft: Automation
        if p.contains("irrigation") || p.contains("water") {
            draft = Automation(name: draftPrompt.isEmpty ? "New Irrigation Flow" : draftPrompt, isEnabled: false, nodes: [
                .init(role: .trigger, title: "Soil moisture < 35%", config: "orchard.*"),
                .init(role: .condition, title: "No rain forecast 24h", config: "weather"),
                .init(role: .action, title: "Open drip valves 20 min", config: "valve.*")
            ], module: .orchard)
        } else if p.contains("oxygen") || p.contains("pond") {
            draft = Automation(name: draftPrompt.isEmpty ? "Pond Safeguard" : draftPrompt, isEnabled: false, nodes: [
                .init(role: .trigger, title: "Dissolved O\u{2082} < 5 mg/L", config: "pond.oxygen"),
                .init(role: .action, title: "Activate aerators", config: "aerator.all"),
                .init(role: .action, title: "Notify owner", config: "push")
            ], module: .pond)
        } else {
            draft = Automation(name: draftPrompt.isEmpty ? "Custom Flow" : draftPrompt, isEnabled: false, nodes: [
                .init(role: .trigger, title: "When condition met", config: "—"),
                .init(role: .action, title: "Perform action", config: "—")
            ], module: .home)
        }
        withAnimation(.prvioMorph) { pendingDraft = draft }
    }

    public func confirmDraft() {
        guard let d = pendingDraft else { return }
        twin.addAutomation(d)
        withAnimation(.prvioMorph) { pendingDraft = nil; draftPrompt = "" }
    }

    public func discardDraft() { withAnimation(.prvioMorph) { pendingDraft = nil } }
}

public struct AutomationStudioView: View {
    @State private var vm: AutomationStudioViewModel

    public init(vm: AutomationStudioViewModel) { self._vm = State(initialValue: vm) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                composer
                if let draft = vm.pendingDraft { draftCard(draft) }
                Text("Active Flows").font(.prvioHeadline())
                ForEach(vm.automations) { automation in
                    FlowCard(automation: automation) { vm.toggle(automation) }
                }
            }
            .padding(Spacing.md)
            .padding(.top, 60)
            .padding(.bottom, 60)
        }
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial).ignoresSafeArea()
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Describe an automation", systemImage: "wand.and.stars").font(.prvioHeadline())
            HStack {
                TextField("e.g. Water the orchard at dawn when dry", text: $vm.draftPrompt)
                    .font(.prvioLabel())
                Button { vm.generateDraft() } label: {
                    Image(systemName: "sparkles").font(.title3).foregroundStyle(.prvioHorizon)
                }.buttonStyle(.plain)
            }
            .padding(Spacing.md)
            .liquidGlass(.modal, tint: .prvioMist)
        }
    }

    private func draftCard(_ draft: Automation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("PRVIO drafted a flow", systemImage: "sparkles").font(.prvioLabel()).foregroundStyle(.prvioHorizon)
            FlowCanvas(automation: draft)
            HStack {
                GlassButton("Enable", systemImage: "checkmark", tint: .healthThriving) { vm.confirmDraft() }
                GlassButton("Discard", systemImage: "xmark", tint: .domainSecurity) { vm.discardDraft() }
            }
        }
        .padding(Spacing.md)
        .liquidGlass(.modal, tint: .prvioHorizon)
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Flow rendering

private struct FlowCard: View {
    var automation: Automation
    var onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: automation.module.icon).foregroundStyle(automation.module.tint)
                Text(automation.name).font(.prvioLabel())
                Spacer()
                Toggle("", isOn: Binding(get: { automation.isEnabled }, set: { _ in onToggle() }))
                    .labelsHidden().tint(automation.module.tint)
            }
            FlowCanvas(automation: automation)
        }
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: automation.module.tint, interactive: false)
        .opacity(automation.isEnabled ? 1 : 0.55)
    }
}

/// Horizontal trigger → condition → action node graph.
private struct FlowCanvas: View {
    var automation: Automation
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(automation.nodes.enumerated()), id: \.offset) { idx, node in
                    NodeChip(node: node)
                    if idx < automation.nodes.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct NodeChip: View {
    var node: Automation.Node
    private var color: Color {
        switch node.role {
        case .trigger: return .domainEnergy
        case .condition: return .domainWater
        case .action: return .healthThriving
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(node.role.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            Text(node.title).font(.prvioCaption()).lineLimit(2)
        }
        .frame(width: 120, alignment: .leading)
        .padding(Spacing.sm)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(color.opacity(0.6), lineWidth: 1))
    }
}
