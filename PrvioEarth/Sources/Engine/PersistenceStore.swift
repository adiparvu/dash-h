//
//  PersistenceStore.swift
//  PRVIO EARTH
//
//  Entity persistence backed by SwiftData with an automatic CloudKit sync
//  layer so twins sync across devices via the user's iCloud container.
//  Falls back gracefully to local-only storage when CloudKit entitlements
//  are absent (simulator, CI, builds without a provisioned container).
//  The public API is unchanged so callers need no updates.
//

import Foundation
import SwiftData

// MARK: - SwiftData model

/// Single-row archive: the entity list is stored as an ISO-8601-encoded JSON
/// blob so it inherits the existing Codable stack without a schema migration
/// whenever `PropertyEntity` gains new fields.
@Model
final class EntityArchive {
    @Attribute(.unique) var key: String
    var payload: Data
    var savedAt: Date

    init(key: String, payload: Data, savedAt: Date) {
        self.key = key
        self.payload = payload
        self.savedAt = savedAt
    }
}

// MARK: - Store

public final class PersistenceStore {
    public static let shared = PersistenceStore()

    private let container: ModelContainer
    // mainContext is @MainActor-isolated; callers are always on the main thread via SwiftUI.
    private var context: ModelContext { MainActor.assumeIsolated { container.mainContext } }

    private init() {
        // CloudKit-backed container — requires iCloud entitlements in production.
        if let ck = try? ModelContainer(
            for: EntityArchive.self,
            configurations: ModelConfiguration(cloudKitDatabase: .automatic)) {
            container = ck
        // Local persistent store — simulator, CI and non-iCloud builds.
        } else if let local = try? ModelContainer(for: EntityArchive.self) {
            container = local
        // In-memory last resort so the app never hard-crashes on a corrupt store.
        } else {
            container = try! ModelContainer(
                for: EntityArchive.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    public func save(entities: [PropertyEntity]) {
        guard let data = try? encoder.encode(entities) else { return }
        let all = try? context.fetch(FetchDescriptor<EntityArchive>())
        if let existing = all?.first(where: { $0.key == "primary" }) {
            existing.payload = data
            existing.savedAt = .now
        } else {
            context.insert(EntityArchive(key: "primary", payload: data, savedAt: .now))
        }
        try? context.save()
    }

    public func loadEntities() -> [PropertyEntity]? {
        guard let all = try? context.fetch(FetchDescriptor<EntityArchive>()),
              let archive = all.first(where: { $0.key == "primary" }) else { return nil }
        return try? decoder.decode([PropertyEntity].self, from: archive.payload)
    }

    public func clear() {
        if let all = try? context.fetch(FetchDescriptor<EntityArchive>()) {
            for item in all { context.delete(item) }
        }
        try? context.save()
    }
}
