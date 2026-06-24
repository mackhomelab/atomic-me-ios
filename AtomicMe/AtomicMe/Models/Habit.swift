//
//  Habit.swift
//  AtomicMe
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var iconSystemName: String = "checkmark.circle"
    var colorHex: String = "#34C759"
    var category: HabitCategory = HabitCategory.wellness
    /// Legacy: when `category == .custom`, kept for migration only.
    /// New code uses the `customCategory` relationship for the label + color.
    var customCategoryName: String = ""
    var customCategory: CustomCategory?
    var notes: String = ""
    var createdAt: Date = Date()
    /// Date the habit becomes active in routines. nil means active immediately.
    var phaseInDate: Date?
    var isArchived: Bool = false
    /// When true, this habit shows a list icon that opens a per-habit
    /// todo list (e.g. "Todo Time" → today's working items).
    var hasTodoList: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \HabitInstance.habit)
    var instances: [HabitInstance]? = []

    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    var completions: [HabitCompletion]? = []

    @Relationship(deleteRule: .cascade, inverse: \TodoItem.habit)
    var todos: [TodoItem]? = []

    init(
        name: String,
        iconSystemName: String = "checkmark.circle",
        colorHex: String = "#34C759",
        category: HabitCategory = .wellness,
        customCategory: CustomCategory? = nil,
        customCategoryName: String = "",
        notes: String = "",
        phaseInDate: Date? = nil,
        hasTodoList: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.iconSystemName = iconSystemName
        self.colorHex = colorHex
        self.category = category
        self.customCategory = customCategory
        self.customCategoryName = customCategoryName
        self.notes = notes
        self.createdAt = Date()
        self.phaseInDate = phaseInDate
        self.isArchived = false
        self.hasTodoList = hasTodoList
    }

    /// Color comes from the category — built-in categories use their fixed
    /// tint, custom categories pull from their CustomCategory record.
    /// Legacy custom habits without a linked CustomCategory fall back to
    /// the stored colorHex so old data still renders.
    var color: Color {
        if category == .custom {
            if let customCategory {
                return customCategory.color
            }
            return Color(hex: colorHex) ?? .gray
        }
        return category.tint
    }

    var isPhasedIn: Bool {
        guard let phaseInDate else { return true }
        return phaseInDate <= Date()
    }

    /// Category label. Prefers the linked CustomCategory, then the legacy
    /// stored string, then the enum's raw value.
    var displayCategory: String {
        if category == .custom {
            if let customCategory, !customCategory.name.isEmpty {
                return customCategory.name
            }
            if !customCategoryName.isEmpty {
                return customCategoryName
            }
        }
        return category.rawValue
    }

    /// Number of unchecked todos attached to this habit.
    var incompleteTodoCount: Int {
        (todos ?? []).filter { !$0.isCompleted }.count
    }
}

enum HabitCategory: String, Codable, CaseIterable, Identifiable {
    case exercise = "Exercise"
    case mindfulness = "Mindfulness"
    case wellness = "Wellness"
    case learning = "Learning"
    case productivity = "Productivity"
    case nutrition = "Nutrition"
    case custom = "Custom"

    var id: String { rawValue }

    var iconSystemName: String {
        switch self {
        case .exercise: return "figure.run"
        case .mindfulness: return "brain.head.profile"
        case .wellness: return "heart.fill"
        case .learning: return "book.fill"
        case .productivity: return "checkmark.circle.fill"
        case .nutrition: return "leaf.fill"
        case .custom: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .exercise: return .orange
        case .mindfulness: return .purple
        case .wellness: return .pink
        case .learning: return .blue
        case .productivity: return .green
        case .nutrition: return .mint
        case .custom: return .gray
        }
    }
}

extension Color {
    init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        guard hexString.count == 6, let value = UInt64(hexString, radix: 16) else {
            return nil
        }
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
