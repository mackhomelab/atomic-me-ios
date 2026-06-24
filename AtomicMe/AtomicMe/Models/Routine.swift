//
//  Routine.swift
//  AtomicMe
//

import Foundation
import SwiftData
import SwiftUI

/// A named stack of habits scheduled for a specific day of the week
/// (e.g. "Morning Routine" on Monday). Each Routine owns ordered HabitInstances.
///
/// If `overrideDate` is set, the routine is a one-off for that single date and
/// is excluded from the weekly template.
@Model
final class Routine {
    var id: UUID = UUID()
    var name: String = ""
    var iconSystemName: String = "sun.max.fill"
    /// 1 = Sunday … 7 = Saturday (matches Calendar.component(.weekday))
    var dayOfWeek: Int = 2
    var timeOfDay: TimeOfDay = TimeOfDay.morning
    /// Order of routines within a single day.
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    /// Scheduled start time (24h). Used for ordering, display, and notifications.
    var startHour: Int = 7
    var startMinute: Int = 0
    /// When true, schedule a local notification at startHour:startMinute.
    var notificationsEnabled: Bool = false
    /// When non-nil, this routine is a one-off for that exact date instead of
    /// part of the weekly template. Use for travel days / vacations.
    var overrideDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \HabitInstance.routine)
    var habitInstances: [HabitInstance]? = []

    init(
        name: String,
        iconSystemName: String = "sun.max.fill",
        dayOfWeek: Int,
        timeOfDay: TimeOfDay = .morning,
        sortOrder: Int = 0,
        startHour: Int = 7,
        startMinute: Int = 0,
        notificationsEnabled: Bool = false,
        overrideDate: Date? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.iconSystemName = iconSystemName
        self.dayOfWeek = dayOfWeek
        self.timeOfDay = timeOfDay
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.startHour = startHour
        self.startMinute = startMinute
        self.notificationsEnabled = notificationsEnabled
        self.overrideDate = overrideDate
    }

    var orderedHabits: [HabitInstance] {
        (habitInstances ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Total minutes since midnight — used for chronological sorting.
    var minutesIntoDay: Int {
        startHour * 60 + startMinute
    }

    var startTimeLabel: String {
        let components = DateComponents(hour: startHour, minute: startMinute)
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(.dateTime.hour().minute())
    }

    /// True when this routine is a one-off for a specific date.
    var isOverride: Bool { overrideDate != nil }
}

enum TimeOfDay: String, Codable, CaseIterable, Identifiable {
    case morning = "Morning"
    case lunch = "Lunch"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"

    var id: String { rawValue }

    var iconSystemName: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .lunch: return "fork.knife"
        case .afternoon: return "sun.haze.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var tint: Color {
        switch self {
        case .morning: return .orange
        case .lunch: return .yellow
        case .afternoon: return .yellow
        case .evening: return .pink
        case .night: return .indigo
        }
    }

    /// Suggested default time of day. The Edit-Day flow uses this for the
    /// initial picker value when creating a new routine.
    var defaultStart: (hour: Int, minute: Int) {
        switch self {
        case .morning: return (7, 0)
        case .lunch: return (12, 0)
        case .afternoon: return (15, 0)
        case .evening: return (18, 30)
        case .night: return (21, 30)
        }
    }
}

enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: return "S"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }

    var fullLabel: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    static func from(date: Date, calendar: Calendar = .current) -> Weekday {
        let weekday = calendar.component(.weekday, from: date)
        return Weekday(rawValue: weekday) ?? .monday
    }
}
