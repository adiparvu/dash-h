//
//  NotificationEngine.swift
//  PRVIO EARTH
//
//  Schedules and delivers local UserNotifications from PRVIO insights.
//  Only critical and warning severity insights are surfaced as push alerts.
//  Runs on iOS only; on visionOS the engine compiles but does nothing so
//  the module graph stays intact.
//

import Foundation

#if os(iOS)
import UserNotifications

@MainActor
public final class NotificationEngine {
    public static let shared = NotificationEngine()
    private init() {}

    // MARK: - Permission

    public func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Schedule insights as notifications

    public func schedule(_ insights: [PrvioInsight]) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let actionable = insights.filter { $0.severity == .critical || $0.severity == .warning }
            for insight in actionable.prefix(5) {
                let content = UNMutableNotificationContent()
                content.title = insight.severity == .critical ? "⚠️ " + insight.title : insight.title
                content.body = insight.detail + (insight.recommendation.map { " " + $0 } ?? "")
                content.sound = insight.severity == .critical ? .defaultCritical : .default
                content.categoryIdentifier = insight.module.rawValue

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "prvio.\(insight.id.uuidString)",
                    content: content,
                    trigger: trigger)
                center.add(request)
            }
        }
    }

    // MARK: - Clear delivered

    public func clearDelivered() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

#else

@MainActor
public final class NotificationEngine {
    public static let shared = NotificationEngine()
    private init() {}
    public func requestAuthorization() async {}
    public func schedule(_ insights: [PrvioInsight]) {}
    public func clearDelivered() {}
}

#endif
