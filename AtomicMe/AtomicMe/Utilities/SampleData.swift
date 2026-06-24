//
//  SampleData.swift
//  AtomicMe
//

import Foundation
import SwiftData

/// Seeds the model context the first time the app launches so the user
/// has something to look at instead of an empty plan.
enum SampleData {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Routine>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        // Core habits.
        let drinkWater = Habit(name: "Drink Water", iconSystemName: "drop.fill", colorHex: "#0A84FF", category: .wellness)
        let meditate   = Habit(name: "Meditate",    iconSystemName: "brain.head.profile", colorHex: "#AF52DE", category: .mindfulness)
        let stretch    = Habit(name: "Stretch",     iconSystemName: "figure.flexibility", colorHex: "#FF9500", category: .exercise)
        let read       = Habit(name: "Read",        iconSystemName: "book.fill", colorHex: "#0A84FF", category: .learning)
        let journal    = Habit(name: "Journal",     iconSystemName: "book.closed.fill", colorHex: "#AF52DE", category: .mindfulness)

        // Phased-in habits (visible on the roadmap).
        let coldShower = Habit(
            name: "Cold Shower",
            iconSystemName: "drop.fill",
            colorHex: "#0A84FF",
            category: .exercise,
            phaseInDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())
        )
        let spanish = Habit(
            name: "Learn Spanish",
            iconSystemName: "character.book.closed.fill",
            colorHex: "#0A84FF",
            category: .learning,
            phaseInDate: Calendar.current.date(byAdding: .day, value: 21, to: Date())
        )

        for habit in [drinkWater, meditate, stretch, read, journal, coldShower, spanish] {
            context.insert(habit)
        }

        // Create morning + evening routines for every day of the week.
        let morningStack: [Habit] = [drinkWater, meditate, stretch]
        let eveningStack: [Habit] = [read, journal]

        for weekday in 1...7 {
            let morning = Routine(
                name: "Morning Routine",
                iconSystemName: "sun.max.fill",
                dayOfWeek: weekday,
                timeOfDay: .morning,
                sortOrder: 0,
                startHour: 7,
                startMinute: 0
            )
            context.insert(morning)
            for (idx, habit) in morningStack.enumerated() {
                let instance = HabitInstance(habit: habit, routine: morning, sortOrder: idx)
                context.insert(instance)
            }

            let evening = Routine(
                name: "Evening Routine",
                iconSystemName: "moon.stars.fill",
                dayOfWeek: weekday,
                timeOfDay: .evening,
                sortOrder: 1,
                startHour: 21,
                startMinute: 0
            )
            context.insert(evening)
            for (idx, habit) in eveningStack.enumerated() {
                let instance = HabitInstance(habit: habit, routine: evening, sortOrder: idx)
                context.insert(instance)
            }
        }

        // Sprinkle a few past completions so Progress isn't empty.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in 1...14 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            // Most days, complete water + read + meditate. Skip a couple to add variety.
            if offset % 4 != 0 {
                context.insert(HabitCompletion(habit: drinkWater, date: day))
                context.insert(HabitCompletion(habit: read, date: day))
            }
            if offset % 3 != 0 {
                context.insert(HabitCompletion(habit: meditate, date: day))
            }
            if offset % 5 != 0 {
                context.insert(HabitCompletion(habit: stretch, date: day))
            }
        }

        try? context.save()
    }
}
