//
//  TodoListView.swift
//  AtomicMe
//

import SwiftUI
import SwiftData

/// Working list attached to a single habit. Add, check off, reorder, and
/// clear completed items. Designed for habits like "Todo Time" where you
/// want a list of things to work on during the habit's window.
struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var habit: Habit

    @State private var newItemTitle: String = ""
    @FocusState private var newItemFocused: Bool

    private var sortedItems: [TodoItem] {
        (habit.todos ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
    private var activeItems: [TodoItem] {
        sortedItems.filter { !$0.isCompleted }
    }
    private var completedItems: [TodoItem] {
        sortedItems.filter { $0.isCompleted }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: habit.iconSystemName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(habit.color)
                            .frame(width: 28, height: 28)
                            .background(habit.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                        TextField("Add a todo…", text: $newItemTitle)
                            .focused($newItemFocused)
                            .submitLabel(.done)
                            .onSubmit(addItem)
                        if !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button(action: addItem) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(habit.color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if activeItems.isEmpty && completedItems.isEmpty {
                    Section {
                        Text("No todos yet. Jot something down above to work on during this habit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !activeItems.isEmpty {
                    Section {
                        ForEach(activeItems, id: \.id) { item in
                            todoRow(item)
                        }
                        .onMove(perform: moveActive)
                        .onDelete(perform: deleteActive)
                    } header: {
                        Text("\(activeItems.count) to do")
                    }
                }

                if !completedItems.isEmpty {
                    Section {
                        ForEach(completedItems, id: \.id) { item in
                            todoRow(item)
                        }
                        .onDelete(perform: deleteCompleted)
                        Button(role: .destructive) {
                            clearCompleted()
                        } label: {
                            Label("Clear completed", systemImage: "trash")
                        }
                    } header: {
                        Text("Completed")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
    }

    private func todoRow(_ item: TodoItem) -> some View {
        Button {
            toggle(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(item.isCompleted ? habit.color : Color.secondary.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
                Text(item.title)
                    .strikethrough(item.isCompleted, color: .secondary)
                    .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let nextOrder = ((habit.todos ?? []).map { $0.sortOrder }.max() ?? -1) + 1
        let item = TodoItem(title: trimmed, habit: habit, sortOrder: nextOrder)
        modelContext.insert(item)
        try? modelContext.save()
        newItemTitle = ""
        newItemFocused = true
    }

    private func toggle(_ item: TodoItem) {
        item.isCompleted.toggle()
        item.completedAt = item.isCompleted ? Date() : nil
        try? modelContext.save()
    }

    private func moveActive(from source: IndexSet, to destination: Int) {
        var working = activeItems
        working.move(fromOffsets: source, toOffset: destination)
        for (idx, item) in working.enumerated() {
            item.sortOrder = idx
        }
        try? modelContext.save()
    }

    private func deleteActive(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(activeItems[index])
        }
        try? modelContext.save()
    }

    private func deleteCompleted(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(completedItems[index])
        }
        try? modelContext.save()
    }

    private func clearCompleted() {
        for item in completedItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

#Preview {
    TodoListPreview()
}

@MainActor
private struct TodoListPreview: View {
    var body: some View {
        let container = PreviewSupport.container
        let habit = (try? container.mainContext.fetch(FetchDescriptor<Habit>()))?.first
        return Group {
            if let habit {
                TodoListView(habit: habit)
                    .modelContainer(container)
            } else {
                Text("No habit available")
            }
        }
    }
}
