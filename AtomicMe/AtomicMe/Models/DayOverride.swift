//
//  DayOverride.swift
//  AtomicMe
//

import Foundation
import SwiftData

/// Marks a single date as "overridden". When an override exists for a date,
/// the TodayView ignores that day's weekly templates and only shows routines
/// whose `overrideDate` matches.
@Model
final class DayOverride {
    var id: UUID = UUID()
    var date: Date = Date()
    /// Optional note: "Travel", "Vacation", etc.
    var notes: String = ""
    var createdAt: Date = Date()

    init(date: Date, notes: String = "") {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.notes = notes
        self.createdAt = Date()
    }
}
