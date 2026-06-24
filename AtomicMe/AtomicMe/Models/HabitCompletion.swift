//
//  HabitCompletion.swift
//  AtomicMe
//

import Foundation
import SwiftData

/// A single recorded completion for a habit on a given calendar day.
/// `date` is always normalized to the start of that day.
///
/// `instance` ties the completion to a specific placement of the habit
/// inside a routine, so the same habit appearing in two routines on the
/// same day can be completed independently. Legacy completions written
/// before this field existed leave it nil and are treated as applying to
/// any instance of the habit on that day.
@Model
final class HabitCompletion {
    var id: UUID = UUID()
    var date: Date = Date()
    var completedAt: Date = Date()
    var habit: Habit?
    var instance: HabitInstance?

    init(habit: Habit, date: Date, instance: HabitInstance? = nil) {
        self.id = UUID()
        self.habit = habit
        self.instance = instance
        self.date = Calendar.current.startOfDay(for: date)
        self.completedAt = Date()
    }
}
