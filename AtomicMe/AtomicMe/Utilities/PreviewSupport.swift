//
//  PreviewSupport.swift
//  AtomicMe
//

import Foundation
import SwiftData

/// In-memory ModelContainer pre-seeded with sample data for SwiftUI previews.
enum PreviewSupport {
    @MainActor
    static let container: ModelContainer = {
        let schema = Schema([
            Habit.self,
            Routine.self,
            HabitInstance.self,
            HabitCompletion.self,
            DayOverride.self,
            TodoItem.self,
            CustomCategory.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            SampleData.seedIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Failed to build preview container: \(error)")
        }
    }()
}
