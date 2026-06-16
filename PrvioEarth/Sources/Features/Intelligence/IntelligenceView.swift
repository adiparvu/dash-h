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

    private let twin: DigitalTwinEngine
    private let ai = AIEngine()
    /// Callback to highlight entities on the underlying map.
    public var onHighlight: ([UUID]) -> Void = { _ in }

    public init(twin: DigitalTwinEngine) { self.twin = twin }

    public let suggestions = [
        "Show stressed trees",
        "Why are my apple trees producing less fruit?",
        "Predict pond health for next week",
        "Create irrigation automation"
    ]

    public func send(_ text: String? = nil) {
        let content = (text ?? draft).trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        messages.append(.init(role: .user, text: content))
        draft = ""

        let reply = ai.respond(to: content, entities: twin.entities, insights: twin.insights)
        withAnimation(.prvioMorph) { messages.append(reply) }
        if !reply.highlightedEntityIDs.isEmpty { onHighlight(reply.highlightedEntityIDs) }
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
                            MessageBubble(message: msg).id(msg.id)
                        }
                    }
                    .padding(Spacing.md)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
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
                ForEach(vm.suggestions, id: \.self) { s in
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
            Image(systemName: "sparkles").foregroundStyle(.prvioHorizon)
            TextField("Ask PRVIO…", text: $vm.draft, axis: .vertical)
                .font(.prvioLabel())
                .onSubmit { vm.send() }
            Button { vm.send() } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(.prvioHorizon)
            }.buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .liquidGlass(.modal, tint: .prvioMist)
        .padding(Spacing.md)
    }
}

private struct MessageBubble: View {
    var message: AssistantMessage
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
            }
            .padding(Spacing.md)
            .liquidGlass(.raised, tint: isUser ? .prvioHorizon : .prvioMist, interactive: false)
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 40) }
        }
    }
}
