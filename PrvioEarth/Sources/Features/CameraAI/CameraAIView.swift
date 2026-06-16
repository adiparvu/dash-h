//
//  CameraAIView.swift
//  PRVIO EARTH
//
//  Live Camera AI surface. Shows a camera feed with real-time detection
//  overlays (bounding boxes + class + confidence) and a strip to switch
//  between cameras. Alerting detections (pest, disease, intrusion) bubble
//  up. Reached from the Systems Hub and from a camera's detail sheet.
//

import SwiftUI

@MainActor
@Observable
public final class CameraAIViewModel {
    public let twin: DigitalTwinEngine
    public let vision: VisionEngine
    public var selectedCameraID: UUID?

    public init(twin: DigitalTwinEngine, vision: VisionEngine, initialCameraID: UUID? = nil) {
        self.twin = twin
        self.vision = vision
        self.cameras = twin.entities.filter { $0.kind == .camera }
        self.selectedCameraID = initialCameraID ?? cameras.first?.id
    }

    public let cameras: [PropertyEntity]

    public func start() {
        vision.startCameraFeed(cameraIDs: cameras.map(\.id))
    }
    public func stop() { vision.stopCameraFeed() }

    public var selectedCamera: PropertyEntity? {
        cameras.first { $0.id == selectedCameraID }
    }
    public var currentFrame: CameraFrame? {
        selectedCameraID.flatMap { vision.frame(for: $0) }
    }
}

public struct CameraAIView: View {
    @State private var vm: CameraAIViewModel

    public init(vm: CameraAIViewModel) { self._vm = State(initialValue: vm) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Camera AI").font(.prvioTitle())
                feed
                if let frame = vm.currentFrame, !frame.detections.isEmpty {
                    detectionList(frame)
                } else {
                    Label("No detections in view", systemImage: "checkmark.circle.fill")
                        .font(.prvioLabel()).foregroundStyle(.secondary)
                        .padding(Spacing.md)
                }
                cameraStrip
            }
            .padding(Spacing.lg)
            .padding(.top, 40)
        }
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial).ignoresSafeArea()
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }

    // MARK: - Feed + overlays

    private var feed: some View {
        GeometryReader { geo in
            ZStack {
                // Camera image placeholder (replaced by AVCaptureVideoPreview / stream)
                LinearGradient(colors: [.prvioDeep, .domainHome.opacity(0.4), .prvioDeep],
                               startPoint: .top, endPoint: .bottom)
                ScanlineSweep()

                // Detection bounding boxes (normalized → view space, origin bottom-left)
                if let frame = vm.currentFrame {
                    ForEach(frame.detections) { det in
                        let box = det.boundingBox
                        let rect = CGRect(
                            x: box.minX * geo.size.width,
                            y: (1 - box.maxY) * geo.size.height,
                            width: box.width * geo.size.width,
                            height: box.height * geo.size.height)
                        BoundingBox(detection: det)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .animation(.prvioSnappy, value: det.id)
                    }
                }

                VStack {
                    HStack {
                        Label(vm.selectedCamera?.name ?? "Camera", systemImage: "video.fill")
                            .font(.prvioCaption())
                            .padding(.horizontal, Spacing.sm).padding(.vertical, 4)
                            .background(Capsule().fill(.ultraThinMaterial))
                        Spacer()
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("LIVE").font(.system(size: 10, weight: .bold))
                    }
                    .padding(Spacing.sm)
                    Spacer()
                }
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.15)))
    }

    private func detectionList(_ frame: CameraFrame) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Detections").font(.prvioHeadline())
            ForEach(frame.detections) { det in
                HStack(spacing: Spacing.md) {
                    Image(systemName: det.classification.symbol)
                        .foregroundStyle(det.classification.isAlerting ? .domainSecurity : .prvioHorizon)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(det.classification.label).font(.prvioLabel())
                        if let note = det.note { Text(note).font(.prvioCaption()).foregroundStyle(.domainSecurity) }
                    }
                    Spacer()
                    Text("\(Int(det.confidence * 100))%").font(.prvioLabel()).foregroundStyle(.secondary)
                }
                .padding(Spacing.md)
                .liquidGlass(.raised, tint: det.classification.isAlerting ? .domainSecurity : .prvioMist, interactive: false)
            }
        }
    }

    private var cameraStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                ForEach(vm.cameras) { cam in
                    Button { withAnimation(.prvioMorph) { vm.selectedCameraID = cam.id } } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "video.fill")
                            Text(cam.name).font(.prvioCaption()).lineLimit(1)
                        }
                        .foregroundStyle(vm.selectedCameraID == cam.id ? .white : .primary)
                        .frame(width: 100, height: 64)
                        .background {
                            if vm.selectedCameraID == cam.id {
                                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.domainHome.gradient)
                            } else {
                                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Overlay components

private struct BoundingBox: View {
    var detection: CameraDetection
    private var color: Color { detection.classification.isAlerting ? .domainSecurity : .healthThriving }
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(color, lineWidth: 2)
            .overlay(alignment: .topLeading) {
                Text("\(detection.classification.label) \(Int(detection.confidence * 100))%")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .offset(y: -16)
            }
            .shadow(color: color.opacity(0.6), radius: 4)
    }
}

/// Subtle moving scanline to convey a live AI analysis feed.
private struct ScanlineSweep: View {
    @State private var y: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .prvioHorizon.opacity(0.35), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 60)
                .offset(y: y * geo.size.height)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) { y = 1 }
                }
        }
        .accessibilityHidden(true)
    }
}
