//
//  OverrideManager.swift
//  AtomicMe
//

import Foundation
import SwiftData

/// Create / clear day overrides. Routines created here have `overrideDate` set
/// so they're invisible to the weekly template logic but show up on that date.
enum OverrideManager {
    /// Create a DayOverride for `date`. If `copyTemplate` is true, the
    /// weekly template routines for that weekday are cloned into one-off
    /// routines stamped with the override date.
    @discardableResult
    static func createOverride(
        for date: Date,
        copyTemplate: Bool,
        notes: String = "",
        allRoutines: [Routine],
        context: ModelContext
    ) -> DayOverride {
        let day = Calendar.current.startOfDay(for: date)
        let override = DayOverride(date: day, notes: notes)
        context.insert(override)

        if copyTemplate {
            let weekday = Calendar.current.component(.weekday, from: day)
            let templates = allRoutines.filter {
                $0.overrideDate == nil && $0.dayOfWeek == weekday
            }
            for template in templates {
                let copy = Routine(
                    name: template.name,
                    iconSystemName: template.iconSystemName,
                    dayOfWeek: weekday,
                    timeOfDay: template.timeOfDay,
                    sortOrder: template.sortOrder,
                    startHour: template.startHour,
                    startMinute: template.startMinute,
                    notificationsEnabled: false,
                    overrideDate: day
                )
                context.insert(copy)
                for instance in template.orderedHabits {
                    guard let habit = instance.habit else { continue }
                    let newInstance = HabitInstance(
                        habit: habit,
                        routine: copy,
                        sortOrder: instance.sortOrder,
                        phaseInDate: instance.phaseInDate
                    )
                    context.insert(newInstance)
                }
            }
        }

        try? context.save()
        return override
    }

    /// Remove the override + its one-off routines, restoring the weekly template.
    static func clearOverride(
        for date: Date,
        overrides: [DayOverride],
        allRoutines: [Routine],
        context: ModelContext
    ) {
        let day = Calendar.current.startOfDay(for: date)
        let calendar = Calendar.current

        for routine in allRoutines where routine.overrideDate.map({ calendar.isDate($0, inSameDayAs: day) }) == true {
            NotificationManager.cancel(routineID: routine.id)
            context.delete(routine)
        }
        for override in overrides where calendar.isDate(override.date, inSameDayAs: day) {
            context.delete(override)
        }
        try? context.save()
    }

    static func overrideExists(for date: Date, in overrides: [DayOverride]) -> Bool {
        let calendar = Calendar.current
        return overrides.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    static func override(for date: Date, in overrides: [DayOverride]) -> DayOverride? {
        let calendar = Calendar.current
        return overrides.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
