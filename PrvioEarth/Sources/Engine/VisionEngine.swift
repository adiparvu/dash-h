//
//  VisionEngine.swift
//  PRVIO EARTH
//
//  Visual intelligence. Two roles:
//   1. Camera AI — turns camera frames into classified detections
//      (people, animals, birds, fish, pests, disease, intrusion).
//   2. Drone pipeline — drives a DroneMission through the OpenDroneMap
//      reconstruction stages and emits the resulting aerial products.
//
//  Production swaps the simulated generators for Vision/Core ML requests
//  and a real ODM job runner; the async API and output types are identical.
//

import Foundation
import CoreGraphics
import Observation

@MainActor
@Observable
public final class VisionEngine {

    /// Most recent frame per camera entity.
    public private(set) var latestFrames: [UUID: CameraFrame] = [:]

    /// Active and completed drone missions.
    public private(set) var missions: [DroneMission] = []

    private var feedTask: Task<Void, Never>?
    private var missionTask: Task<Void, Never>?

    public init(missions: [DroneMission] = []) {
        self.missions = missions
    }

    // MARK: - Camera AI

    /// Begin a simulated detection feed for the given cameras. In production
    /// this consumes the camera streams and runs Vision requests per frame.
    public func startCameraFeed(cameraIDs: [UUID], interval: Duration = .seconds(2)) {
        feedTask?.cancel()
        guard !cameraIDs.isEmpty else { return }
        feedTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let id = cameraIDs.randomElement() else { continue }
                self?.latestFrames[id] = Self.simulateFrame(for: id)
            }
        }
    }

    public func stopCameraFeed() { feedTask?.cancel() }

    public func frame(for cameraID: UUID) -> CameraFrame? { latestFrames[cameraID] }

    /// Aggregate any alerting detections across all cameras.
    public var activeAlerts: [CameraDetection] {
        latestFrames.values.flatMap { $0.detections }.filter { $0.classification.isAlerting }
    }

    private static func simulateFrame(for cameraID: UUID) -> CameraFrame {
        let candidates: [DetectionClass] = [.person, .animal, .bird, .vehicle, .pest, .intrusion]
        let count = Int.random(in: 0...3)
        let detections = (0..<count).map { _ -> CameraDetection in
            let cls = candidates.randomElement()!
            return CameraDetection(
                classification: cls,
                confidence: Double.random(in: 0.62...0.98),
                boundingBox: CGRect(
                    x: Double.random(in: 0.05...0.6),
                    y: Double.random(in: 0.05...0.6),
                    width: Double.random(in: 0.15...0.35),
                    height: Double.random(in: 0.15...0.4)),
                note: cls.isAlerting ? "Flagged for review" : nil)
        }
        return CameraFrame(cameraEntityID: cameraID, detections: detections)
    }

    // MARK: - Drone Pipeline

    public func addMission(_ mission: DroneMission) {
        missions.insert(mission, at: 0)
    }

    /// Advance a planned mission through the OpenDroneMap reconstruction
    /// stages, mutating it in place so the UI can show live progress.
    public func runMission(_ id: UUID, stageInterval: Duration = .seconds(1)) {
        missionTask?.cancel()
        missionTask = Task { [weak self] in
            let stages = DroneMission.Stage.allCases
            for stage in stages {
                if Task.isCancelled { return }
                await MainActor.run { self?.setStage(stage, for: id) }
                if stage != .complete { try? await Task.sleep(for: stageInterval) }
            }
        }
    }

    private func setStage(_ stage: DroneMission.Stage, for id: UUID) {
        guard let idx = missions.firstIndex(where: { $0.id == id }) else { return }
        missions[idx].stage = stage
    }

    public func stop() {
        feedTask?.cancel()
        missionTask?.cancel()
    }
}
