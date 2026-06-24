//
//  HabitInstance.swift
//  AtomicMe
//

import Foundation
import SwiftData

/// A single placement of a Habit inside a Routine. The same Habit can be
/// scheduled in multiple Routines (across days), and order within a routine
/// is captured by `sortOrder` (this is the "stack" position).
///
/// `phaseInDate` is a per-routine pre-assignment: when non-nil, the habit
/// stays hidden from this routine until that date — independent of the
/// habit's own `phaseInDate` (which controls whether the habit is active
/// in the system at all).
@Model
final class HabitInstance {
    var id: UUID = UUID()
    var sortOrder: Int = 0
    var habit: Habit?
    var routine: Routine?
    var phaseInDate: Date?

    /// Completions recorded against this specific placement. Uses
    /// `.nullify` so removing a habit from a routine preserves the
    /// historical completion records (they become "untagged").
    @Relationship(deleteRule: .nullify, inverse: \HabitCompletion.instance)
    var completions: [HabitCompletion]? = []

    init(habit: Habit, routine: Routine, sortOrder: Int, phaseInDate: Date? = nil) {
        self.id = UUID()
        self.habit = habit
        self.routine = routine
        self.sortOrder = sortOrder
        self.phaseInDate = phaseInDate
    }

    /// True when both the habit and this routine-specific pre-assignment
    /// dates have arrived by `date`.
    func isActive(on date: Date) -> Bool {
        if let habitPhase = habit?.phaseInDate, habitPhase > date { return false }
        if let instancePhase = phaseInDate, instancePhase > date { return false }
        return true
    }

    /// The effective pre-assignment date — whichever start date is later.
    /// Used to label "starts Xxx" badges.
    var effectivePhaseInDate: Date? {
        switch (habit?.phaseInDate, phaseInDate) {
        case (nil, nil): return nil
        case (let h?, nil): return h
        case (nil, let i?): return i
        case (let h?, let i?): return max(h, i)
        }
    }
}
