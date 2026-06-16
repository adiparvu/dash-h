//
//  IrrigationLiveActivity.swift
//  PRVIO EARTH — Live Activity
//
//  ActivityKit Live Activity + Dynamic Island for time-bounded property
//  events: irrigation cycles, harvest windows, pond treatments, drone
//  flights. Shows live progress on the Lock Screen and Dynamic Island.
//
//  NOTE: ActivityAttributes must live in a target shared by app + widget.
//

import ActivityKit
import WidgetKit
import SwiftUI

public struct IrrigationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var zone: String
        public var progress: Double        // 0...1
        public var litersDelivered: Double
        public var endsAt: Date
        public init(zone: String, progress: Double, litersDelivered: Double, endsAt: Date) {
            self.zone = zone; self.progress = progress
            self.litersDelivered = litersDelivered; self.endsAt = endsAt
        }
    }
    public var automationName: String
    public init(automationName: String) { self.automationName = automationName }
}

struct IrrigationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IrrigationAttributes.self) { context in
            // Lock Screen / banner
            HStack(spacing: Spacing.md) {
                Image(systemName: "spigot.fill").font(.title2).foregroundStyle(.domainWater)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.automationName).font(.prvioLabel())
                    ProgressView(value: context.state.progress).tint(.domainWater)
                    Text("\(context.state.zone) • \(Int(context.state.litersDelivered)) L")
                        .font(.prvioCaption()).foregroundStyle(.secondary)
                }
                Text(context.state.endsAt, style: .timer).font(.prvioLabel()).monospacedDigit()
            }
            .padding()
            .activityBackgroundTint(Color.prvioDeep)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.zone, systemImage: "spigot.fill").foregroundStyle(.domainWater)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endsAt, style: .timer).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress).tint(.domainWater)
                }
            } compactLeading: {
                Image(systemName: "spigot.fill").foregroundStyle(.domainWater)
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
            } minimal: {
                Image(systemName: "drop.fill").foregroundStyle(.domainWater)
            }
        }
    }
}
