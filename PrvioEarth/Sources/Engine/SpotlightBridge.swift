//
//  SpotlightBridge.swift
//  PRVIO EARTH
//
//  Indexes PropertyEntity objects in CoreSpotlight so users can find trees,
//  ponds and devices via the iOS Search UI without opening the app. Called
//  from DigitalTwinEngine whenever the entity set changes.
//

import Foundation
import CoreSpotlight
import CoreServices

public enum SpotlightBridge {
    private static let domainIdentifier = "com.prvio.earth.entity"

    public static func index(_ entities: [PropertyEntity]) {
        let items = entities.map { entity -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: .item)
            attrs.title = entity.name
            attrs.contentDescription = "\(entity.kind.module.rawValue.capitalized) · Health \(Int(entity.health.score * 100))%"
            attrs.keywords = [entity.kind.rawValue, entity.kind.module.rawValue, "PRVIO", "digital twin",
                              entity.health.status.rawValue]
            attrs.latitude  = NSNumber(value: entity.location.latitude)
            attrs.longitude = NSNumber(value: entity.location.longitude)
            attrs.namedLocation = entity.kind.module.rawValue.capitalized
            // Deep-link: RootView handles CSSearchableItemActionType via the uniqueIdentifier
            attrs.url = URL(string: "prvio://entity/\(entity.id.uuidString)")
            return CSSearchableItem(
                uniqueIdentifier: entity.id.uuidString,
                domainIdentifier: domainIdentifier,
                attributeSet: attrs)
        }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    public static func deindex(_ ids: [UUID]) {
        let stringIDs = ids.map(\.uuidString)
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: stringIDs) { _ in }
    }

    public static func deindexAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { _ in }
    }
}
