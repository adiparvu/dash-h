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
            attrs.contentDescription = "\(entity.kind.module.title) · \(entity.health.status.rawValue.capitalized) · \(Int(entity.health.score * 100))% health"
            attrs.completionDate = entity.lastUpdated

            var keywords = [entity.kind.rawValue, entity.kind.module.rawValue, entity.kind.module.title,
                            "PRVIO", "digital twin", entity.health.status.rawValue]
            switch entity.detail {
            case .tree(let t):    keywords += [t.species, "tree", "carbon", "forest"]
            case .orchard(let o): keywords += [o.species, "orchard", o.phenophase.rawValue, "fruit"]
            case .agriculture(let a): keywords += [a.cropType, "field", a.growthStage.rawValue, "crop"]
            case .pond:           keywords += ["pond", "fish", "water", "oxygen"]
            case .greenhouse:     keywords += ["greenhouse", "climate", "co2", "humidity"]
            case .garden:         keywords += ["garden", "bed", "soil", "moisture"]
            case .device:         keywords += ["device", "sensor", "smart home", "IoT"]
            case .none:           break
            }
            if entity.health.score < 0.4 { keywords.append("critical") }
            if entity.health.score < 0.6 { keywords.append("needs attention") }
            attrs.keywords = keywords

            attrs.latitude     = NSNumber(value: entity.location.latitude)
            attrs.longitude    = NSNumber(value: entity.location.longitude)
            attrs.namedLocation = entity.kind.module.title
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
