//
//  AtomicMeApp.swift
//  AtomicMe
//

import SwiftUI
import SwiftData

@main
struct AtomicMeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Habit.self,
            Routine.self,
            HabitInstance.self,
            HabitCompletion.self,
            DayOverride.self,
            TodoItem.self,
            CustomCategory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
