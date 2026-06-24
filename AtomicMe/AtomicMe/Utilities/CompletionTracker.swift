//
//  CompletionTracker.swift
//  AtomicMe
//

import Foundation
import SwiftData

/// Read/write helpers for HabitCompletion. Keeps "is this habit done today?"
/// logic in one place instead of scattered across views.
enum CompletionTracker {
    static func isCompleted(habit: Habit, on date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return (habit.completions ?? []).contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    @discardableResult
    static func toggle(habit: Habit, on date: Date, context: ModelContext) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        let existing = (habit.completions ?? []).filter {
            Calendar.current.isDate($0.date, inSameDayAs: day)
        }
        if let match = existing.first {
            for completion in existing {
                context.delete(completion)
            }
            _ = match
            try? context.save()
            return false
        } else {
            let completion = HabitCompletion(habit: habit, date: day)
            context.insert(completion)
            try? context.save()
            return true
        }
    }

    static func completionRate(for habits: [Habit], on date: Date) -> Double {
        guard !habits.isEmpty else { return 0 }
        let done = habits.filter { isCompleted(habit: $0, on: date) }.count
        return Double(done) / Double(habits.count)
    }
}
