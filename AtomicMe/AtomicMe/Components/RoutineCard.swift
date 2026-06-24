//
//  RoutineCard.swift
//  AtomicMe
//

import SwiftUI
import SwiftData

/// Card showing a single routine for a day, with its habit stack inside.
struct RoutineCard: View {
    let routine: Routine
    let date: Date
    var onEdit: (() -> Void)? = nil
    var onToggleHabit: ((Habit) -> Void)? = nil
    var onShowTodos: ((Habit) -> Void)? = nil

    private var instances: [HabitInstance] { routine.orderedHabits }

    private var activeInstances: [HabitInstance] {
        instances.filter { $0.isActive(on: date) }
    }

    private var activeHabits: [Habit] {
        activeInstances.compactMap { $0.habit }
    }

    private var completionRate: Double {
        CompletionTracker.completionRate(for: activeHabits, on: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .padding(.horizontal, 12)

            if activeHabits.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(activeHabits, id: \.id) { habit in
                        HabitRow(
                            habit: habit,
                            isCompleted: CompletionTracker.isCompleted(habit: habit, on: date),
                            onToggle: { onToggleHabit?(habit) },
                            onShowTodos: { onShowTodos?(habit) }
                        )
                        if habit.id != activeHabits.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: routine.iconSystemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(routine.timeOfDay.tint)
                .frame(width: 32, height: 32)
                .background(routine.timeOfDay.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(routine.name)
                        .font(.headline)
                    if routine.notificationsEnabled {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(routine.startTimeLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(routine.timeOfDay.tint)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(progressLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            CompletionRing(progress: completionRate, tint: routine.timeOfDay.tint)
                .frame(width: 32, height: 32)

            if onEdit != nil {
                Button(action: { onEdit?() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color(.tertiarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }

    private var progressLabel: String {
        let done = activeHabits.filter { CompletionTracker.isCompleted(habit: $0, on: date) }.count
        return "\(done) of \(activeHabits.count) complete"
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No habits stacked yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if onEdit != nil {
                Button("Add habits", action: { onEdit?() })
                    .font(.caption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

struct CompletionRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)
            Text("\(Int(progress * 100))")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
        }
    }
}
