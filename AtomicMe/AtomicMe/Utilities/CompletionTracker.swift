//
//  CompletionTracker.swift
//  AtomicMe
//

import Foundation
import SwiftData

/// Read/write helpers for HabitCompletion. Keeps "is this habit done today?"
/// logic in one place instead of scattered across views.
///
/// Two granularities are supported:
///   * Instance-level (`isCompleted(instance:)`, `toggle(instance:)`) —
///     each placement of a habit in a routine is tracked independently,
///     so a habit appearing in two routines on the same day toggles
///     separately in each.
///   * Habit-level (`isCompleted(habit:)`) — "was this habit done at all
///     today?", used by progress aggregation.
enum CompletionTracker {
    static func isCompleted(habit: Habit, on date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return (habit.completions ?? []).contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    static func isCompleted(instance: HabitInstance, on date: Date) -> Bool {
        guard let habit = instance.habit else { return false }
        let day = Calendar.current.startOfDay(for: date)
        return (habit.completions ?? []).contains { completion in
            guard Calendar.current.isDate(completion.date, inSameDayAs: day) else { return false }
            // Legacy completions with no instance apply to every placement
            // of the habit (preserves behavior for data written before the
            // instance field existed).
            return completion.instance == nil || completion.instance?.id == instance.id
        }
    }

    @discardableResult
    static func toggle(instance: HabitInstance, on date: Date, context: ModelContext) -> Bool {
        guard let habit = instance.habit else { return false }
        let day = Calendar.current.startOfDay(for: date)
        let matching = (habit.completions ?? []).filter { completion in
            guard Calendar.current.isDate(completion.date, inSameDayAs: day) else { return false }
            return completion.instance == nil || completion.instance?.id == instance.id
        }
        if !matching.isEmpty {
            for completion in matching {
                context.delete(completion)
            }
            try? context.save()
            return false
        } else {
            let completion = HabitCompletion(habit: habit, date: day, instance: instance)
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

    static func completionRate(for instances: [HabitInstance], on date: Date) -> Double {
        guard !instances.isEmpty else { return 0 }
        let done = instances.filter { isCompleted(instance: $0, on: date) }.count
        return Double(done) / Double(instances.count)
    }
}
