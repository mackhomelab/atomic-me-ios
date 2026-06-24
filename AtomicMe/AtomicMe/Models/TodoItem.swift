//
//  TodoItem.swift
//  AtomicMe
//

import Foundation
import SwiftData

/// A working-list item attached to a habit (e.g. the "Todo Time" habit).
/// Persists independently of the habit's daily completion.
@Model
final class TodoItem {
    var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?
    var sortOrder: Int = 0
    var habit: Habit?

    init(title: String, habit: Habit, sortOrder: Int) {
        self.id = UUID()
        self.title = title
        self.habit = habit
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
