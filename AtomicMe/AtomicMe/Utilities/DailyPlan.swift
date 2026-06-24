//
//  DailyPlan.swift
//  AtomicMe
//

import Foundation

/// Resolves what's actually scheduled for a given date — honoring day
/// overrides, the weekly template, and per-instance pre-assignments.
/// Used by both TodayView and ProgressTabView so they agree on completion math.
enum DailyPlan {
    /// Routines that should appear on `date`. When the date has a
    /// DayOverride, only that day's one-off routines are returned; otherwise
    /// the weekly template routines for that weekday are returned.
    static func routines(
        on date: Date,
        allRoutines: [Routine],
        allOverrides: [DayOverride]
    ) -> [Routine] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let hasOverride = allOverrides.contains {
            calendar.isDate($0.date, inSameDayAs: date)
        }
        if hasOverride {
            return allRoutines.filter { routine in
                guard let overrideDate = routine.overrideDate else { return false }
                return calendar.isDate(overrideDate, inSameDayAs: date)
            }
        }
        return allRoutines.filter { $0.overrideDate == nil && $0.dayOfWeek == weekday }
    }

    /// Distinct habits that are actually expected on `date`.
    static func activeHabits(
        on date: Date,
        allRoutines: [Routine],
        allOverrides: [DayOverride]
    ) -> [Habit] {
        let plan = routines(on: date, allRoutines: allRoutines, allOverrides: allOverrides)
        let habits = plan
            .flatMap { $0.orderedHabits }
            .filter { $0.isActive(on: date) }
            .compactMap { $0.habit }
        var seen = Set<UUID>()
        return habits.filter { seen.insert($0.id).inserted }
    }

    /// Completed habits / scheduled habits on `date`. Returns 0 when nothing
    /// is scheduled, so empty days don't drag down the average.
    static func completionRate(
        on date: Date,
        allRoutines: [Routine],
        allOverrides: [DayOverride]
    ) -> Double {
        let habits = activeHabits(on: date, allRoutines: allRoutines, allOverrides: allOverrides)
        return CompletionTracker.completionRate(for: habits, on: date)
    }
}
