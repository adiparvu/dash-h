//
//  SensorGateway.swift
//  PRVIO EARTH
//
//  The ingestion + API layer. Abstracts every telemetry source behind one
//  async stream of `TelemetryFrame`s so the DigitalTwinEngine never knows
//  whether a reading came from Matter, Thread, MQTT, a Zigbee bridge, a
//  drone upload or the cloud sync. Protocol-oriented so transports are
//  swappable and testable.
//

import Foundation

// MARK: - Telemetry

public struct TelemetryFrame: Sendable {
    public var entityID: UUID
    public var metrics: [String: Double]
    public var health: Double?
    public var timestamp: Date
    public init(entityID: UUID, metrics: [String: Double], health: Double? = nil, timestamp: Date = .now) {
        self.entityID = entityID; self.metrics = metrics
        self.health = health; self.timestamp = timestamp
    }
}

// MARK: - Transport Abstraction

/// Any telemetry source (Matter, Thread, MQTT, Zigbee, Z-Wave, drone, cloud).
public protocol TelemetryTransport: Sendable {
    var name: String { get }
    func stream() -> AsyncStream<TelemetryFrame>
}

// MARK: - Gateway

/// Fans multiple transports into a single merged telemetry stream and
/// applies frames to the twin. In production each transport wraps a real
/// SDK (Matter/HomeKit via the Home framework, MQTT via a socket client,
/// drone imagery via the OpenDroneMap pipeline → derived NDVI frames).
public actor SensorGateway {
    private var transports: [TelemetryTransport] = []

    public init() {}

    public func register(_ transport: TelemetryTransport) {
        transports.append(transport)
    }

    /// Merge all transport streams into one.
    public func merged() -> AsyncStream<TelemetryFrame> {
        let sources = transports
        return AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    for source in sources {
                        group.addTask {
                            for await frame in source.stream() {
                                continuation.yield(frame)
                            }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - REST/GraphQL Sync (cloud)

/// Thin async API client for cloud sync, sharing twins across devices and
/// backing the WidgetKit snapshot. Endpoints are versioned and typed.
public struct PrvioAPIClient: Sendable {
    public var baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL; self.session = session
    }

    public func fetchEntities(propertyID: UUID) async throws -> [PropertyEntity] {
        let url = baseURL.appending(path: "v1/properties/\(propertyID)/entities")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder.prvio.decode([PropertyEntity].self, from: data)
    }

    public func pushFrame(_ frame: TelemetryFrame, propertyID: UUID) async throws {
        var req = URLRequest(url: baseURL.appending(path: "v1/properties/\(propertyID)/telemetry"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode([
            "entityID": frame.entityID.uuidString
        ])
        _ = try await session.data(for: req)
    }
}

extension JSONDecoder {
    static var prvio: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

// MARK: - Mock transport for previews/tests

public struct SimulatedTransport: TelemetryTransport {
    public let name = "Simulator"
    public var entityIDs: [UUID]
    public init(entityIDs: [UUID]) { self.entityIDs = entityIDs }

    public func stream() -> AsyncStream<TelemetryFrame> {
        let ids = entityIDs
        return AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    if let id = ids.randomElement() {
                        continuation.yield(TelemetryFrame(
                            entityID: id,
                            metrics: ["temp": Double.random(in: 16...28)]))
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - HomeKit / Matter Transport

#if os(iOS)
import HomeKit

/// Bridges HomeKit and Matter accessories into TelemetryFrames. Each
/// accessory's characteristics are read when HomeKit homes load and
/// notification updates are enabled so readings flow without polling.
/// The entity map ties HomeKit accessory names to DigitalTwinEngine UUIDs;
/// in production this mapping is persisted in the App Group and editable
/// via PropertyEditorView.
public final class HomeKitTransport: NSObject, TelemetryTransport, HMHomeManagerDelegate,
                                     @unchecked Sendable {
    public let name = "HomeKit"

    private let homeManager = HMHomeManager()
    private let entityMap: [String: UUID]   // accessory.name → entity UUID
    private var continuation: AsyncStream<TelemetryFrame>.Continuation?

    public init(entityMap: [String: UUID]) {
        self.entityMap = entityMap
        super.init()
        homeManager.delegate = self
    }

    public func stream() -> AsyncStream<TelemetryFrame> {
        AsyncStream { [weak self] cont in
            self?.continuation = cont
            cont.onTermination = { [weak self] _ in self?.continuation = nil }
        }
    }

    // MARK: HMHomeManagerDelegate

    public func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        for home in manager.homes {
            for accessory in home.accessories {
                guard let entityID = entityMap[accessory.name] else { continue }
                emitFrame(for: accessory, entityID: entityID)
                enableNotifications(for: accessory)
            }
        }
    }

    private func emitFrame(for accessory: HMAccessory, entityID: UUID) {
        var metrics: [String: Double] = [:]
        for service in accessory.services {
            for characteristic in service.characteristics {
                guard let key = Self.metricKey(for: characteristic.characteristicType),
                      let number = characteristic.value as? NSNumber else { continue }
                metrics[key] = number.doubleValue
            }
        }
        guard !metrics.isEmpty else { return }
        continuation?.yield(TelemetryFrame(entityID: entityID, metrics: metrics))
    }

    private func enableNotifications(for accessory: HMAccessory) {
        for service in accessory.services {
            for characteristic in service.characteristics {
                guard Self.metricKey(for: characteristic.characteristicType) != nil else { continue }
                characteristic.enableNotification(true) { _ in }
            }
        }
    }

    /// Maps HomeKit / Matter characteristic type UUIDs to PRVIO metric keys.
    private static func metricKey(for typeUUID: String) -> String? {
        switch typeUUID {
        case HMCharacteristicTypeCurrentTemperature:      return "temp"
        case HMCharacteristicTypeCurrentRelativeHumidity: return "humidity"
        case HMCharacteristicTypeOn:                      return "power"
        case HMCharacteristicTypeBatteryLevel:            return "battery"
        case HMCharacteristicTypeAirQuality:              return "airQuality"
        case HMCharacteristicTypeCarbonDioxideLevel:      return "co2"
        default:                                           return nil
        }
    }
}
#endif
