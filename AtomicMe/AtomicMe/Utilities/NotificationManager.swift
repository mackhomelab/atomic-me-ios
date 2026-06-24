//
//  NotificationManager.swift
//  AtomicMe
//

import Foundation
import UserNotifications

/// Schedules local notifications for routines. One pending notification per
/// routine, keyed by routine.id. Re-scheduling cancels the previous one first.
enum NotificationManager {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func schedule(routine: Routine) async {
        cancel(routineID: routine.id)
        guard routine.notificationsEnabled else { return }

        let status = await currentAuthorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = routine.name
        content.body = "Time to start your \(routine.timeOfDay.rawValue.lowercased()) stack."
        content.sound = .default

        let trigger: UNNotificationTrigger
        if let overrideDate = routine.overrideDate {
            // One-off day: fire once at the exact date/time.
            let calendar = Calendar.current
            let target = calendar.date(
                bySettingHour: routine.startHour,
                minute: routine.startMinute,
                second: 0,
                of: overrideDate
            ) ?? overrideDate
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: target
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            // Weekly template: repeat each week on the same weekday + time.
            var components = DateComponents()
            components.weekday = routine.dayOfWeek
            components.hour = routine.startHour
            components.minute = routine.startMinute
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }

        let request = UNNotificationRequest(
            identifier: identifier(for: routine.id),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel(routineID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: routineID)])
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private static func identifier(for routineID: UUID) -> String {
        "routine-\(routineID.uuidString)"
    }
}
