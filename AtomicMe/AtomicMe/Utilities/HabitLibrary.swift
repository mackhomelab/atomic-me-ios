//
//  HabitLibrary.swift
//  AtomicMe
//

import Foundation

/// Curated, ready-to-add habits shown in the "Add Habit" library.
struct HabitTemplate: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let iconSystemName: String
    let colorHex: String
    let category: HabitCategory
}

enum HabitLibrary {
    static let all: [HabitTemplate] = [
        // Exercise
        HabitTemplate(name: "Stretch",        iconSystemName: "figure.flexibility", colorHex: "#FF9500", category: .exercise),
        HabitTemplate(name: "Walk 20 minutes", iconSystemName: "figure.walk",       colorHex: "#FF9500", category: .exercise),
        HabitTemplate(name: "Workout",        iconSystemName: "dumbbell.fill",      colorHex: "#FF9500", category: .exercise),
        HabitTemplate(name: "Run",            iconSystemName: "figure.run",         colorHex: "#FF9500", category: .exercise),
        HabitTemplate(name: "Cold Shower",    iconSystemName: "drop.fill",          colorHex: "#0A84FF", category: .exercise),

        // Mindfulness
        HabitTemplate(name: "Meditate",       iconSystemName: "brain.head.profile", colorHex: "#AF52DE", category: .mindfulness),
        HabitTemplate(name: "Breathwork",     iconSystemName: "wind",               colorHex: "#AF52DE", category: .mindfulness),
        HabitTemplate(name: "Journal",        iconSystemName: "book.closed.fill",   colorHex: "#AF52DE", category: .mindfulness),
        HabitTemplate(name: "Gratitude",      iconSystemName: "heart.text.square.fill", colorHex: "#AF52DE", category: .mindfulness),

        // Wellness
        HabitTemplate(name: "Drink Water",    iconSystemName: "drop.fill",          colorHex: "#0A84FF", category: .wellness),
        HabitTemplate(name: "Skincare",       iconSystemName: "sparkles",           colorHex: "#FF2D55", category: .wellness),
        HabitTemplate(name: "Floss",          iconSystemName: "mouth.fill",         colorHex: "#FF2D55", category: .wellness),
        HabitTemplate(name: "Sleep by 10pm",  iconSystemName: "bed.double.fill",    colorHex: "#5856D6", category: .wellness),

        // Learning
        HabitTemplate(name: "Read",           iconSystemName: "book.fill",          colorHex: "#0A84FF", category: .learning),
        HabitTemplate(name: "Learn Spanish",  iconSystemName: "character.book.closed.fill", colorHex: "#0A84FF", category: .learning),
        HabitTemplate(name: "Practice Music", iconSystemName: "music.note",         colorHex: "#0A84FF", category: .learning),

        // Productivity
        HabitTemplate(name: "Plan the Day",   iconSystemName: "calendar",           colorHex: "#34C759", category: .productivity),
        HabitTemplate(name: "Inbox Zero",     iconSystemName: "tray.fill",          colorHex: "#34C759", category: .productivity),
        HabitTemplate(name: "Deep Work",      iconSystemName: "timer",              colorHex: "#34C759", category: .productivity),

        // Nutrition
        HabitTemplate(name: "Eat Vegetables", iconSystemName: "leaf.fill",          colorHex: "#30D158", category: .nutrition),
        HabitTemplate(name: "Vitamins",       iconSystemName: "pills.fill",         colorHex: "#30D158", category: .nutrition),
        HabitTemplate(name: "No Sugar",       iconSystemName: "xmark.octagon.fill", colorHex: "#30D158", category: .nutrition),
    ]

    static func grouped() -> [(HabitCategory, [HabitTemplate])] {
        HabitCategory.allCases.compactMap { category in
            let matches = all.filter { $0.category == category }
            return matches.isEmpty ? nil : (category, matches)
        }
    }
}
