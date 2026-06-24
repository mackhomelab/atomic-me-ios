//
//  TodayView.swift
//  AtomicMe
//

import SwiftUI
import SwiftData

/// Main screen. Shows the selected day's routines and the habit stack
/// inside each. Mirrors the first mockup tile.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Routine.sortOrder), SortDescriptor(\Routine.createdAt)])
    private var allRoutines: [Routine]
    @Query private var allOverrides: [DayOverride]

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var editingRoutine: Routine?
    @State private var showingEditDay: Bool = false
    @State private var showingOverridePrompt: Bool = false
    @State private var todosForHabit: Habit?

    private var calendar: Calendar { Calendar.current }

    private var weekday: Int {
        calendar.component(.weekday, from: selectedDate)
    }

    private var override: DayOverride? {
        OverrideManager.override(for: selectedDate, in: allOverrides)
    }

    /// Routines visible for the selected date. Sorted chronologically.
    private var routinesForDay: [Routine] {
        DailyPlan.routines(
            on: selectedDate,
            allRoutines: allRoutines,
            allOverrides: allOverrides
        )
        .sorted { lhs, rhs in
            if lhs.minutesIntoDay != rhs.minutesIntoDay { return lhs.minutesIntoDay < rhs.minutesIntoDay }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var allActiveHabits: [Habit] {
        DailyPlan.activeHabits(
            on: selectedDate,
            allRoutines: allRoutines,
            allOverrides: allOverrides
        )
    }

    private var overallRate: Double {
        CompletionTracker.completionRate(for: allActiveHabits, on: selectedDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    WeekStripPager(selectedDate: $selectedDate)
                        .padding(.horizontal, 4)
                    if override != nil {
                        overrideBanner
                    }
                    routineList
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Atomic Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !calendar.isDateInToday(selectedDate) {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation {
                                selectedDate = calendar.startOfDay(for: Date())
                            }
                        } label: {
                            Label("Today", systemImage: "scope")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditDay) {
                EditDayView(date: selectedDate)
                    .environment(\.modelContext, modelContext)
            }
            .sheet(item: $editingRoutine) { routine in
                HabitStackView(routine: routine)
                    .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showingOverridePrompt) {
                OverrideCreatorSheet(date: selectedDate, allRoutines: allRoutines)
            }
            .sheet(item: $todosForHabit) { habit in
                TodoListView(habit: habit)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(relativeDayLabel)
                        .font(.title3.weight(.semibold))
                    Text(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                CompletionRing(progress: overallRate, tint: .accentColor)
                    .frame(width: 48, height: 48)
            }

            ProgressView(value: overallRate)
                .tint(.accentColor)

            HStack {
                if isFutureDay {
                    Label("Planning ahead", systemImage: "calendar.badge.clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Label("\(Int(overallRate * 100))% complete", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button {
                        showingEditDay = true
                    } label: {
                        Label("Edit \(relativeDayLabel)", systemImage: "calendar.badge.plus")
                    }
                    if override == nil {
                        Button {
                            showingOverridePrompt = true
                        } label: {
                            Label("Override for one day", systemImage: "calendar.badge.exclamationmark")
                        }
                    } else {
                        Button(role: .destructive) {
                            OverrideManager.clearOverride(
                                for: selectedDate,
                                overrides: allOverrides,
                                allRoutines: allRoutines,
                                context: modelContext
                            )
                        } label: {
                            Label("Revert to weekly template", systemImage: "arrow.uturn.backward")
                        }
                    }
                } label: {
                    Label("Edit day", systemImage: "calendar.badge.plus")
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var overrideBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 32, height: 32)
                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text("One-off plan")
                    .font(.subheadline.weight(.semibold))
                if let notes = override?.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Custom routines just for \(selectedDate.formatted(.dateTime.month().day()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                OverrideManager.clearOverride(
                    for: selectedDate,
                    overrides: allOverrides,
                    allRoutines: allRoutines,
                    context: modelContext
                )
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption.weight(.semibold))
                    .padding(8)
                    .background(Color(.tertiarySystemBackground), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }

    private var relativeDayLabel: String {
        if calendar.isDateInToday(selectedDate) { return "Today" }
        if calendar.isDateInTomorrow(selectedDate) { return "Tomorrow" }
        if calendar.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.weekday(.wide))
    }

    private var isFutureDay: Bool {
        selectedDate > calendar.startOfDay(for: Date())
    }

    private var routineList: some View {
        VStack(spacing: 14) {
            if routinesForDay.isEmpty {
                emptyState
            } else {
                ForEach(routinesForDay, id: \.id) { routine in
                    RoutineCard(
                        routine: routine,
                        date: selectedDate,
                        onEdit: { editingRoutine = routine },
                        onToggleInstance: { instance in
                            CompletionTracker.toggle(instance: instance, on: selectedDate, context: modelContext)
                        },
                        onShowTodos: { habit in
                            todosForHabit = habit
                        }
                    )
                }
            }

            Button {
                showingEditDay = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add routine to this day")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sun.and.horizon.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("No routines yet")
                .font(.headline)
            Text("Tap \"Edit day\" to build your first stack for \(selectedDate.formatted(.dateTime.weekday(.wide))).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

/// Asks how to bootstrap a one-off day plan (copy template or start blank)
/// and records a DayOverride for that date.
private struct OverrideCreatorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let allRoutines: [Routine]

    @State private var notes: String = ""
    @State private var copyTemplate: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(date.formatted(.dateTime.weekday(.wide).month().day().year()))
                        .font(.headline)
                    Text("This date will use its own routines instead of the weekly template.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Reason (optional)") {
                    TextField("e.g. Travel day, Vacation, Sick", text: $notes)
                }
                Section {
                    Toggle("Start from weekly template", isOn: $copyTemplate)
                } footer: {
                    Text(copyTemplate
                         ? "Copies the routines from this weekday so you can tweak them."
                         : "Starts with an empty day so you can plan it from scratch.")
                }
            }
            .navigationTitle("Override Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Override") {
                        OverrideManager.createOverride(
                            for: date,
                            copyTemplate: copyTemplate,
                            notes: notes.trimmingCharacters(in: .whitespaces),
                            allRoutines: allRoutines,
                            context: modelContext
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewSupport.container)
}
