//
//  WatchSessionBridge.swift
//  PRVIO EARTH
//
//  WatchConnectivity bridge that keeps the Apple Watch companion in sync
//  with the live twin. The iOS side pushes a serialised TwinSnapshot on
//  every insight recompute; the watchOS side decodes it and makes it
//  available as @Observable state so WatchTwinView re-renders instantly.
//  Falls back to updateApplicationContext when the watch is not reachable.
//

#if canImport(WatchConnectivity)
import WatchConnectivity
import Foundation

enum WatchMessageKey {
    static let snapshot = "prvio_snapshot"
}

@MainActor
@Observable
public final class WatchSessionBridge: NSObject, WCSessionDelegate {
    public static let shared = WatchSessionBridge()

    /// The most recently received TwinSnapshot from the paired device.
    public var latestSnapshot: TwinSnapshot?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - iOS: push a snapshot to the watch companion

    #if os(iOS)
    public func send(_ snapshot: TwinSnapshot) {
        guard WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let payload: [String: Any] = [WatchMessageKey.snapshot: data]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(payload)
        }
    }
    #endif

    // MARK: - WCSessionDelegate

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?) {}

    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.ingestPayload(message) }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.ingestPayload(applicationContext) }
    }

    private func ingestPayload(_ dict: [String: Any]) {
        guard let data = dict[WatchMessageKey.snapshot] as? Data,
              let snap = try? JSONDecoder().decode(TwinSnapshot.self, from: data) else { return }
        latestSnapshot = snap
    }

    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated public func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
#endif
