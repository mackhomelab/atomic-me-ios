//
//  SettingsView.swift
//  AtomicMe
//

import SwiftUI
import SwiftData

/// App settings — currently focused on data management
/// (clear everything, wipe just completions, or reseed sample data).
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var habits: [Habit]
    @Query private var routines: [Routine]
    @Query private var completions: [HabitCompletion]
    @Query private var overrides: [DayOverride]
    @Query private var todos: [TodoItem]
    @Query private var customCategories: [CustomCategory]

    @State private var confirmingAction: DestructiveAction?
    @State private var toastMessage: String?

    enum DestructiveAction: Identifiable {
        case clearCompletions
        case clearEverything
        case reseed

        var id: String {
            switch self {
            case .clearCompletions: return "clearCompletions"
            case .clearEverything:  return "clearEverything"
            case .reseed:           return "reseed"
            }
        }

        var title: String {
            switch self {
            case .clearCompletions: return "Clear completion history?"
            case .clearEverything:  return "Erase all data?"
            case .reseed:           return "Replace with sample data?"
            }
        }

        var message: String {
            switch self {
            case .clearCompletions:
                return "Deletes every checked-off completion but keeps your habits and routines."
            case .clearEverything:
                return "Deletes every habit, routine, and completion. This cannot be undone."
            case .reseed:
                return "Erases your current data and loads the starter morning + evening routines."
            }
        }

        var confirmLabel: String {
            switch self {
            case .clearCompletions: return "Clear History"
            case .clearEverything:  return "Erase Everything"
            case .reseed:           return "Reset to Sample"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("At a glance") {
                    statRow(label: "Habits", value: habits.filter { !$0.isArchived }.count, system: "checklist")
                    statRow(label: "Routines", value: routines.count, system: "list.bullet.rectangle")
                    statRow(label: "Completions logged", value: completions.count, system: "checkmark.seal.fill")
                }

                Section {
                    Button {
                        confirmingAction = .clearCompletions
                    } label: {
                        Label("Clear completion history", systemImage: "arrow.counterclockwise")
                    }

                    Button(role: .destructive) {
                        confirmingAction = .clearEverything
                    } label: {
                        Label("Erase all data", systemImage: "trash")
                    }

                    Button {
                        confirmingAction = .reseed
                    } label: {
                        Label("Reset to sample data", systemImage: "sparkles")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Atomic Me stores all data on this device only.")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: URL(string: "https://jamesclear.com/atomic-habits")!) {
                        Label("Atomic Habits by James Clear", systemImage: "book.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .alert(item: $confirmingAction) { action in
                Alert(
                    title: Text(action.title),
                    message: Text(action.message),
                    primaryButton: .destructive(Text(action.confirmLabel)) {
                        perform(action)
                    },
                    secondaryButton: .cancel()
                )
            }
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private func statRow(label: String, value: Int, system: String) -> some View {
        HStack {
            Label(label, systemImage: system)
            Spacer()
            Text("\(value)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func perform(_ action: DestructiveAction) {
        switch action {
        case .clearCompletions:
            deleteAllCompletions()
            showToast("Completion history cleared")
        case .clearEverything:
            deleteEverything()
            showToast("All data erased")
        case .reseed:
            deleteEverything()
            SampleData.seedIfNeeded(context: modelContext)
            showToast("Sample data restored")
        }
    }

    private func deleteAllCompletions() {
        for completion in completions {
            modelContext.delete(completion)
        }
        try? modelContext.save()
    }

    private func deleteEverything() {
        // Cancel every pending notification first so old reminders can't
        // fire after a wipe.
        NotificationManager.cancelAll()
        // Order matters: delete child rows first so SwiftData doesn't trip
        // on dangling relationship references.
        for completion in completions {
            modelContext.delete(completion)
        }
        for todo in todos {
            modelContext.delete(todo)
        }
        for override in overrides {
            modelContext.delete(override)
        }
        for routine in routines {
            modelContext.delete(routine)
        }
        for habit in habits {
            modelContext.delete(habit)
        }
        for category in customCategories {
            modelContext.delete(category)
        }
        try? modelContext.save()
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(duration: 0.3)) {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    toastMessage = nil
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewSupport.container)
}
