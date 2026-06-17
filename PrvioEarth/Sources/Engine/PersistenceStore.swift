//
//  PersistenceStore.swift
//  PRVIO EARTH
//
//  Lightweight JSON persistence for the twin entity list. Writes atomically
//  to the app's Documents directory so entities survive restarts. Phase 1
//  bridge — SwiftData + CloudKit replace this in Phase 1 production; the
//  API is identical so the swap is mechanical.
//

import Foundation

public final class PersistenceStore {
    public static let shared = PersistenceStore()
    private init() {}

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var fileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("prvio_twin_v1.json")
    }

    private struct Archive: Codable {
        var entities: [PropertyEntity]
        var savedAt: Date
    }

    public func save(entities: [PropertyEntity]) {
        guard let url = fileURL else { return }
        let archive = Archive(entities: entities, savedAt: .now)
        guard let data = try? encoder.encode(archive) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public func loadEntities() -> [PropertyEntity]? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let archive = try? decoder.decode(Archive.self, from: data) else { return nil }
        return archive.entities
    }

    public func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
