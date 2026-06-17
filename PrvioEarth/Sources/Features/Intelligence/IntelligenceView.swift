//
//  IntelligenceView.swift
//  PRVIO EARTH
//
//  PRVIO Intelligence — the conversational property advisor. Floats over
//  the twin as a Liquid Glass panel. Answers natural-language questions,
//  highlights entities on the map and proposes automations. Backed by the
//  AIEngine (on-device Apple Intelligence in production).
//

import SwiftUI

@MainActor
@Observable
public final class IntelligenceViewModel {
    public var messages: [AssistantMessage] = [
        .init(role: .prvio, text: "Hello — I'm PRVIO Intelligence. Ask me anything about your property. Try \"Show stressed trees\" or \"Predict pond health for next week.\"")
    ]
    public var draft: String = ""
    public var isTyping: Bool = false

    private let twin: DigitalTwinEngine
    private let ai = AIEngine()
    /// Callback to highlight entities on the underlying map.
    public var onHighlight: ([UUID]) -> Void = { _ in }

    public init(twin: DigitalTwinEngine) { self.twin = twin }

    /// Context-aware suggestion chips — lead with insight-driven prompts, fallback to evergreens.
    public var dynamicSuggestions: [String] {
        var chips: [String] = []
        let live = twin.insights
        // Module-health driven chips
        if live.contains(where: { $0.module == .pond && $0.severity >= .warning }) { chips.append("What's wrong with the pond?") }
        if live.contains(where: { $0.module == .forest && $0.severity >= .warning }) { chips.append("Show stressed trees") }
        if live.contains(where: { $0.module == .greenhouse }) { chips.append("Greenhouse status") }
        if live.contains(where: { $0.module == .agriculture && $0.severity >= .warning }) { chips.append("Check field health") }
        // Weather-insight driven chips (from Batch 25 weather insights feed)
        if live.contains(where: { $0.title.localizedCaseInsensitiveContains("frost") }) { chips.append("Will it frost tonight?") }
        if live.contains(where: { $0.title.localizedCaseInsensitiveContains("dry spell") || $0.title.localizedCaseInsensitiveContains("drought") }) { chips.append("Should I irrigate today?") }
        if live.contains(where: { $0.title.localizedCaseInsensitiveContains("heat wave") || $0.title.localizedCaseInsensitiveContains("high wind") }) { chips.append("Weather impact on crops?") }
        let fallback = ["Energy overview", "Predict pond health", "Why less apple fruit?", "Create irrigation automation"]
        for f in fallback where chips.count < 4 { chips.append(f) }
        return Array(chips.prefix(4))
    }

    public var entityNameMap: [UUID: String] {
        Dictionary(uniqueKeysWithValues: twin.entities.map { ($0.id, $0.name) })
    }

    public var conversationExport: String {
        var lines = [
            "PRVIO Intelligence — Conversation Export",
            "Date: \(Date().formatted(.dateTime.day().month().year().hour().minute()))",
            String(repeating: "-", count: 44),
            "",
        ]
        for msg in messages {
            let prefix = msg.role == .user ? "You" : "PRVIO"
            lines.append("\(prefix): \(msg.text)")
            for insight in msg.insights { lines.append("  • \(insight.title)") }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    public func clearChat() {
        let greeting = AssistantMessage(role: .prvio,
            text: "Hello — I'm PRVIO Intelligence. Ask me anything about your property. Try \"Show stressed trees\" or \"Predict pond health for next week.\"")
        withAnimation(.prvioMorph) { messages = [greeting] }
    }

    public func send(_ text: String? = nil) {
        let content = (text ?? draft).trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        messages.append(.init(role: .user, text: content))
        draft = ""
        isTyping = true

        // Snapshot to avoid data-race across the await suspension point.
        let entities = twin.entities
        let insights = twin.insights
        let wx = twin.latestWeather
        let fc = twin.latestForecast

        Task { @MainActor in
            let reply: AssistantMessage
            #if canImport(FoundationModels)
            if #available(iOS 26, *) {
                reply = await ai.respondIntelligence(to: content, entities: entities, insights: insights)
            } else {
                reply = ai.respond(to: content, entities: entities, insights: insights, weather: wx, forecast: fc)
            }
            #else
            reply = ai.respond(to: content, entities: entities, insights: insights, weather: wx, forecast: fc)
            #endif
            isTyping = false
            withAnimation(.prvioMorph) { messages.append(reply) }
            if !reply.highlightedEntityIDs.isEmpty { onHighlight(reply.highlightedEntityIDs) }
        }
    }
}

public struct IntelligenceView: View {
    @State private var vm: IntelligenceViewModel

    public init(vm: IntelligenceViewModel) { self._vm = State(initialValue: vm) }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(vm.messages) { msg in
                            MessageBubble(message: msg, entityNames: vm.entityNameMap).id(msg.id)
                        }
                        if vm.isTyping {
                            TypingBubble()
                                .id("typing")
                                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
                        }
                    }
                    .padding(Spacing.md)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
                .onChange(of: vm.isTyping) { _, typing in
                    if typing { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                }
            }
            suggestionRow
            composer
        }
        .background(.clear)
    }

    private var suggestionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(vm.dynamicSuggestions, id: \.self) { s in
                    Button { vm.send(s) } label: {
                        Text(s).font(.prvioCaption())
                            .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                            .liquidGlass(.raised, tint: .prvioMist, interactive: false)
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, Spacing.md)
        }
    }

    private var composer: some View {
        HStack(spacing: Spacing.sm) {
            Button { vm.clearChat() } label: {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear conversation")
            Image(systemName: "sparkles").foregroundStyle(.prvioHorizon)
            TextField("Ask PRVIO…", text: $vm.draft, axis: .vertical)
                .font(.prvioLabel())
                .onSubmit { vm.send() }
            ShareLink(item: vm.conversationExport,
                      subject: Text("PRVIO Intelligence Conversation"),
                      message: Text("Exported from PRVIO EARTH")) {
                Image(systemName: "square.and.arrow.up").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export conversation")
            Button { vm.send() } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(.prvioHorizon)
            }.buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .liquidGlass(.modal, tint: .prvioMist)
        .padding(Spacing.md)
    }
}

// MARK: - Typing indicator

private struct TypingBubble: View {
    var body: some View {
        HStack {
            TimelineView(.animation(minimumInterval: 0.45)) { ctx in
                let phase = Int(ctx.date.timeIntervalSinceReferenceDate / 0.45) % 3
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 7, height: 7)
                            .scaleEffect(phase == i ? 1.4 : 0.7)
                            .animation(.easeInOut(duration: 0.3), value: phase)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm + 4)
                .liquidGlass(.raised, tint: .prvioMist, interactive: false)
            }
            Spacer(minLength: 40)
        }
        .accessibilityLabel("PRVIO Intelligence is typing")
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    var message: AssistantMessage
    var entityNames: [UUID: String] = [:]
    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(message.text).font(.prvioLabel())
                ForEach(message.insights) { insight in
                    HStack(spacing: 6) {
                        Image(systemName: insight.severity.symbol).font(.caption)
                        Text(insight.title).font(.prvioCaption())
                    }.foregroundStyle(.secondary)
                }
                if !message.highlightedEntityIDs.isEmpty {
                    entityChips
                }
            }
            .padding(Spacing.md)
            .liquidGlass(.raised, tint: isUser ? .prvioHorizon : .prvioMist, interactive: false)
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 40) }
        }
    }

    private var entityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(message.highlightedEntityIDs.prefix(5), id: \.self) { id in
                    if let name = entityNames[id] {
                        Text(name)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Capsule().fill(Color.prvioHorizon.opacity(0.2)))
                            .foregroundStyle(.prvioHorizon)
                    }
                }
            }
        }
        .accessibilityLabel("\(message.highlightedEntityIDs.count) entities highlighted on map")
    }
}
