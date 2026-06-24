//
//  HabitCompletion.swift
//  AtomicMe
//

import Foundation
import SwiftData

/// A single recorded completion for a habit on a given calendar day.
/// `date` is always normalized to the start of that day.
@Model
final class HabitCompletion {
    var id: UUID = UUID()
    var date: Date = Date()
    var completedAt: Date = Date()
    var habit: Habit?

    init(habit: Habit, date: Date) {
        self.id = UUID()
        self.habit = habit
        self.date = Calendar.current.startOfDay(for: date)
        self.completedAt = Date()
    }
}
