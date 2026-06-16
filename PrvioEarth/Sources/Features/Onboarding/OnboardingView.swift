//
//  OnboardingView.swift
//  PRVIO EARTH
//
//  First-run experience. Apple Invites / Journal in spirit: a few full-bleed
//  Liquid Glass panels over a softly animated globe, ending by "materializing"
//  the Digital Twin. Sets a persisted flag so it shows only once.
//

import SwiftUI

@MainActor
@Observable
public final class OnboardingViewModel {
    public var step: Int = 0
    public var propertyName: String = "My Property"
    public var didFinish: Bool

    public init() {
        self.didFinish = UserDefaults.standard.bool(forKey: Self.key)
    }

    static let key = "prvio.onboarding.complete"
    public let lastStep = 3

    public func advance() {
        if step < lastStep { withAnimation(.prvioMorph) { step += 1 } }
        else { finish() }
    }

    public func finish() {
        UserDefaults.standard.set(true, forKey: Self.key)
        withAnimation(.prvioFluid) { didFinish = true }
    }
}

public struct OnboardingView: View {
    @State private var vm = OnboardingViewModel()
    var onComplete: (String) -> Void

    public init(onComplete: @escaping (String) -> Void) { self.onComplete = onComplete }

    private let pages: [(icon: String, title: String, body: String, tint: Color)] = [
        ("globe.americas.fill", "Welcome to PRVIO EARTH",
         "A living Digital Twin of your entire property — home, pond, orchard, forest and more, in one place.", .prvioHorizon),
        ("hand.tap.fill", "Touch your property",
         "Everything is on the map. Tap any tree, pump, pond or camera to inspect, predict and automate it.", .domainForest),
        ("sparkles", "Meet PRVIO Intelligence",
         "Ask anything. \u{201C}Show stressed trees.\u{201D} \u{201C}Predict pond health.\u{201D} \u{201C}Create irrigation automation.\u{201D}", .domainPond),
        ("mappin.and.ellipse", "Locate your property",
         "We\u{2019}ll anchor your twin and start streaming live data from your sensors and systems.", .domainOrchard),
    ]

    public var body: some View {
        ZStack {
            // Ambient animated backdrop
            LinearGradient(colors: [.prvioDeep, pages[vm.step].tint.opacity(0.5), .prvioDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: vm.step)

            GlobePulse(tint: pages[vm.step].tint)

            VStack(spacing: Spacing.xl) {
                Spacer()
                panel
                if vm.step == vm.lastStep { nameField }
                controls
            }
            .padding(Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .onChange(of: vm.didFinish) { _, done in if done { onComplete(vm.propertyName) } }
    }

    private var panel: some View {
        let page = pages[vm.step]
        return VStack(spacing: Spacing.md) {
            Image(systemName: page.icon)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(page.tint)
                .shadow(color: page.tint.opacity(0.6), radius: 16)
                .transition(.scale.combined(with: .opacity))
                .id("icon\(vm.step)")
            Text(page.title).font(.prvioTitle()).multilineTextAlignment(.center)
            Text(page.body).font(.prvioLabel()).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .liquidGlass(.modal, tint: page.tint)
        .id("panel\(vm.step)")
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
    }

    private var nameField: some View {
        HStack {
            Image(systemName: "house.fill").foregroundStyle(.prvioHorizon)
            TextField("Property name", text: $vm.propertyName).font(.prvioLabel())
        }
        .padding(Spacing.md)
        .liquidGlass(.raised, tint: .prvioMist, interactive: false)
        .transition(.opacity)
    }

    private var controls: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                ForEach(0...vm.lastStep, id: \.self) { i in
                    Capsule()
                        .fill(i == vm.step ? pages[vm.step].tint : Color.white.opacity(0.25))
                        .frame(width: i == vm.step ? 22 : 7, height: 7)
                        .animation(.prvioSnappy, value: vm.step)
                }
            }
            GlassButton(vm.step == vm.lastStep ? "Generate my Twin" : "Continue",
                        systemImage: vm.step == vm.lastStep ? "sparkles" : "arrow.right",
                        tint: pages[vm.step].tint) { vm.advance() }
                .frame(maxWidth: .infinity)
        }
    }
}

/// Slow-breathing concentric rings evoking a globe / radar sweep.
private struct GlobePulse: View {
    var tint: Color
    @State private var animate = false
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(tint.opacity(0.3 - Double(i) * 0.08), lineWidth: 1.5)
                    .frame(width: 180 + CGFloat(i) * 120, height: 180 + CGFloat(i) * 120)
                    .scaleEffect(animate ? 1.08 : 0.96)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true).delay(Double(i) * 0.3), value: animate)
            }
        }
        .blur(radius: 0.5)
        .offset(y: -60)
        .onAppear { animate = true }
    }
}
