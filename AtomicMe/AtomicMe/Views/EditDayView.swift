//
//  EditDayView.swift
//  AtomicMe
//

import SwiftUI
import SwiftData

/// Edit screen for the routines visible on the given date. Operates on the
/// weekly template unless the date has a DayOverride, in which case it
/// edits that day's one-off routines.
struct EditDayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @Query private var allRoutines: [Routine]
    @Query private var allOverrides: [DayOverride]

    @State private var routineToOpen: Routine?
    @State private var showingNewRoutineSheet: Bool = false
    @State private var showingOverrideSheet: Bool = false

    private var calendar: Calendar { Calendar.current }
    private var weekday: Int { calendar.component(.weekday, from: date) }

    private var override: DayOverride? {
        OverrideManager.override(for: date, in: allOverrides)
    }

    private var routines: [Routine] {
        let filtered: [Routine]
        if override != nil {
            filtered = allRoutines.filter { routine in
                guard let overrideDate = routine.overrideDate else { return false }
                return calendar.isDate(overrideDate, inSameDayAs: date)
            }
        } else {
            filtered = allRoutines.filter { $0.overrideDate == nil && $0.dayOfWeek == weekday }
        }
        return filtered.sorted { lhs, rhs in
            if lhs.minutesIntoDay != rhs.minutesIntoDay { return lhs.minutesIntoDay < rhs.minutesIntoDay }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    headerCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    if override != nil {
                        Button(role: .destructive) {
                            OverrideManager.clearOverride(
                                for: date,
                                overrides: allOverrides,
                                allRoutines: allRoutines,
                                context: modelContext
                            )
                        } label: {
                            Label("Revert to weekly template", systemImage: "arrow.uturn.backward")
                        }
                    } else {
                        Button {
                            showingOverrideSheet = true
                        } label: {
                            Label("Override this day", systemImage: "calendar.badge.exclamationmark")
                        }
                    }
                } footer: {
                    Text(override != nil
                         ? "This day uses one-off routines. Reverting deletes them and restores the weekly template."
                         : "Override a date for travel, vacation, or any one-off plan without changing your weekly template.")
                }

                Section("Routines") {
                    if routines.isEmpty {
                        Text("No routines yet. Add one below.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(routines, id: \.id) { routine in
                            routineRow(routine: routine)
                        }
                        .onDelete(perform: deleteRoutines)
                    }
                }

                Section {
                    Button {
                        showingNewRoutineSheet = true
                    } label: {
                        Label("Add Routine", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Edit Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $routineToOpen) { routine in
                HabitStackView(routine: routine)
            }
            .sheet(isPresented: $showingNewRoutineSheet) {
                NewRoutineSheet(
                    date: date,
                    isOverride: override != nil,
                    existingMaxOrder: (routines.map { $0.sortOrder }.max() ?? -1)
                ) { newRoutine in
                    routineToOpen = newRoutine
                }
            }
            .sheet(isPresented: $showingOverrideSheet) {
                OverrideCreatorSheet(date: date, allRoutines: allRoutines)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.wide)))
                .font(.title2.bold())
            Text(date.formatted(.dateTime.month().day().year()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(override != nil
                 ? "Editing a one-off plan for this specific date."
                 : "Changes apply to every \(date.formatted(.dateTime.weekday(.wide))).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func routineRow(routine: Routine) -> some View {
        let active = routine.orderedHabits.filter { $0.isActive(on: date) }
        let total = routine.orderedHabits.count
        let upcoming = total - active.count
        return Button {
            routineToOpen = routine
        } label: {
            HStack(spacing: 12) {
                Image(systemName: routine.iconSystemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(routine.timeOfDay.tint)
                    .frame(width: 32, height: 32)
                    .background(routine.timeOfDay.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(routine.name)
                            .font(.subheadline.weight(.semibold))
                        if routine.notificationsEnabled {
                            Image(systemName: "bell.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 6) {
                        Text("\(routine.startTimeLabel) · \(active.count) habit\(active.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if upcoming > 0 {
                            Text("(+\(upcoming) upcoming)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func deleteRoutines(at offsets: IndexSet) {
        for index in offsets {
            let routine = routines[index]
            NotificationManager.cancel(routineID: routine.id)
            modelContext.delete(routine)
        }
        try? modelContext.save()
    }
}

// MARK: - Sub-sheets

/// Asks how to bootstrap a one-off day plan and creates the override.
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
                    TextField("e.g. Travel, Vacation, Sick", text: $notes)
                }
                Section {
                    Toggle("Start from weekly template", isOn: $copyTemplate)
                } footer: {
                    Text(copyTemplate
                         ? "Copies routines from this weekday so you can tweak them."
                         : "Starts with an empty day so you can plan from scratch.")
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

/// Form to create a brand new routine for the given date.
private struct NewRoutineSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let isOverride: Bool
    let existingMaxOrder: Int
    var onCreated: (Routine) -> Void

    @State private var name: String = ""
    @State private var timeOfDay: TimeOfDay = .morning
    @State private var startTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @State private var notificationsOn: Bool = false
    @State private var permissionDenied: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Morning Routine", text: $name)
                }
                Section("Time of day") {
                    Picker("Time of day", selection: $timeOfDay) {
                        ForEach(TimeOfDay.allCases) { tod in
                            Label(tod.rawValue, systemImage: tod.iconSystemName).tag(tod)
                        }
                    }
                    .onChange(of: timeOfDay) { _, newValue in
                        let defaults = newValue.defaultStart
                        startTime = Calendar.current.date(
                            from: DateComponents(hour: defaults.hour, minute: defaults.minute)
                        ) ?? startTime
                    }
                }
                Section("Start time") {
                    DatePicker("Start at", selection: $startTime, displayedComponents: .hourAndMinute)
                }
                Section {
                    Toggle("Notify me", isOn: $notificationsOn)
                    if permissionDenied {
                        Text("Notifications are disabled in Settings.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } footer: {
                    Text("Get a reminder when it's time to start this routine.")
                }
            }
            .navigationTitle("New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await create() }
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if notificationsOn {
            let granted = await NotificationManager.requestAuthorization()
            if !granted {
                permissionDenied = true
                notificationsOn = false
            }
        }

        let components = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        let weekday = Calendar.current.component(.weekday, from: date)
        let routine = Routine(
            name: trimmed,
            iconSystemName: timeOfDay.iconSystemName,
            dayOfWeek: weekday,
            timeOfDay: timeOfDay,
            sortOrder: existingMaxOrder + 1,
            startHour: components.hour ?? 7,
            startMinute: components.minute ?? 0,
            notificationsEnabled: notificationsOn,
            overrideDate: isOverride ? Calendar.current.startOfDay(for: date) : nil
        )
        modelContext.insert(routine)
        try? modelContext.save()

        if notificationsOn {
            await NotificationManager.schedule(routine: routine)
        }

        onCreated(routine)
        dismiss()
    }
}

#Preview {
    EditDayView(date: Date())
        .modelContainer(PreviewSupport.container)
}
