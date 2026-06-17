//
//  LiveActivityAttributes.swift
//  PRVIO EARTH
//
//  ActivityKit attributes shared between the main app (which starts/updates
//  activities) and the Widget Extension (which renders them). Lives in the
//  Core framework so both targets can import it cleanly.
//

import ActivityKit

public struct IrrigationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var zone: String
        public var progress: Double          // 0...1
        public var litersDelivered: Double
        public var endsAt: Date

        public init(zone: String, progress: Double, litersDelivered: Double, endsAt: Date) {
            self.zone = zone
            self.progress = progress
            self.litersDelivered = litersDelivered
            self.endsAt = endsAt
        }
    }

    public var automationName: String
    public init(automationName: String) { self.automationName = automationName }
}
