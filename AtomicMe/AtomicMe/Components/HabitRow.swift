//
//  HabitRow.swift
//  AtomicMe
//

import SwiftUI

/// One habit inside a routine card. Tapping the row toggles completion.
/// Habits with a todo list show a small list button on the right that
/// opens that habit's TodoListView.
struct HabitRow: View {
    let habit: Habit
    let isCompleted: Bool
    var showsChevron: Bool = false
    var trailingAccessory: AnyView? = nil
    var onToggle: (() -> Void)? = nil
    var onShowTodos: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: habit.iconSystemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(habit.color)
                .frame(width: 32, height: 32)
                .background(habit.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .strikethrough(isCompleted, color: .secondary)
                    .foregroundStyle(isCompleted ? Color.secondary : Color.primary)
                Text(habit.displayCategory)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if habit.hasTodoList, let onShowTodos {
                todoButton(action: onShowTodos)
            }

            if let trailingAccessory {
                trailingAccessory
            } else if onToggle != nil {
                Button {
                    onToggle?()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(isCompleted ? Color.accentColor : Color.secondary.opacity(0.5))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle?()
        }
    }

    private func todoButton(action: @escaping () -> Void) -> some View {
        let count = habit.incompleteTodoCount
        return Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(habit.color)
                    .frame(width: 32, height: 32)
                    .background(habit.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.red, in: Capsule())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
