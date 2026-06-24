//
//  HabitStackView.swift
//  AtomicMe
//

import SwiftUI
import SwiftData

/// Editor for a single routine. Lets you change the routine's schedule
/// (name, time of day, start time, notifications), reorder its habit
/// stack, copy the routine to other days, or delete it.
struct HabitStackView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var routine: Routine

    @State private var showingAddHabit: Bool = false
    @State private var editMode: EditMode = .active
    @State private var editingInstance: HabitInstance?
    @State private var showingCopySheet: Bool = false
    @State private var notificationPermissionDenied: Bool = false

    private var instances: [HabitInstance] {
        routine.orderedHabits
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: routine.startHour, minute: routine.startMinute)
                ) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                routine.startHour = comps.hour ?? routine.startHour
                routine.startMinute = comps.minute ?? routine.startMinute
                try? modelContext.save()
                Task { await NotificationManager.schedule(routine: routine) }
            }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { routine.notificationsEnabled },
            set: { newValue in
                Task { await setNotifications(newValue) }
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Routine name", text: $routine.name)
                        .onSubmit { try? modelContext.save() }
                    Picker("Time of day", selection: $routine.timeOfDay) {
                        ForEach(TimeOfDay.allCases) { tod in
                            Label(tod.rawValue, systemImage: tod.iconSystemName).tag(tod)
                        }
                    }
                    .onChange(of: routine.timeOfDay) { _, _ in
                        try? modelContext.save()
                        Task { await NotificationManager.schedule(routine: routine) }
                    }
                    DatePicker(
                        "Start at",
                        selection: startTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    Toggle("Notify me", isOn: notificationsBinding)
                    if notificationPermissionDenied {
                        Label("Notifications are disabled in Settings.", systemImage: "bell.slash")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    if let overrideDate = routine.overrideDate {
                        Text("This routine is a one-off for \(overrideDate.formatted(.dateTime.month().day())).")
                    } else {
                        Text("Applies every \(Weekday(rawValue: routine.dayOfWeek)?.fullLabel ?? "")")
                    }
                }

                Section {
                    if instances.isEmpty {
                        emptyState
                    } else {
                        ForEach(instances, id: \.id) { instance in
                            stackRow(for: instance)
                        }
                        .onMove(perform: move)
                        .onDelete(perform: delete)
                    }
                } header: {
                    HStack {
                        Text("Habit Stack")
                        Spacer()
                        Text("\(instances.count)")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Drag to reorder. Stacking pairs new habits with ones you already do — the first habit triggers the next.")
                }

                Section {
                    Button {
                        showingAddHabit = true
                    } label: {
                        Label("Add Habit", systemImage: "plus.circle.fill")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        deleteRoutine()
                    } label: {
                        Label("Delete routine", systemImage: "trash")
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .listStyle(.insetGrouped)
            .navigationTitle(routine.name.isEmpty ? "Routine" : routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddHabit = true
                        } label: {
                            Label("Add Habit", systemImage: "plus")
                        }
                        if routine.overrideDate == nil {
                            Button {
                                showingCopySheet = true
                            } label: {
                                Label("Copy to other days…", systemImage: "doc.on.doc")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView(routine: routine)
            }
            .sheet(item: $editingInstance) { instance in
                InstanceStartDateSheet(instance: instance)
            }
            .sheet(isPresented: $showingCopySheet) {
                RoutineCopySheet(routine: routine)
            }
        }
    }

    private func stackRow(for instance: HabitInstance) -> some View {
        Button {
            editingInstance = instance
        } label: {
            HStack(spacing: 12) {
                if let habit = instance.habit {
                    Image(systemName: habit.iconSystemName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(habit.color)
                        .frame(width: 32, height: 32)
                        .background(habit.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name).font(.subheadline.weight(.semibold))
                        HStack(spacing: 6) {
                            Text(habit.displayCategory)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let phase = instance.effectivePhaseInDate, phase > Date() {
                                Label("starts \(phase.formatted(.dateTime.month().day()))",
                                      systemImage: "calendar.badge.clock")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } else {
                    Text("Missing habit")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("This stack is empty")
                .font(.subheadline.weight(.semibold))
            Text("Tap Add Habit below to start linking habits together.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var working = instances
        working.move(fromOffsets: source, toOffset: destination)
        for (idx, instance) in working.enumerated() {
            instance.sortOrder = idx
        }
        try? modelContext.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(instances[index])
        }
        try? modelContext.save()
    }

    private func deleteRoutine() {
        NotificationManager.cancel(routineID: routine.id)
        modelContext.delete(routine)
        try? modelContext.save()
        dismiss()
    }

    private func setNotifications(_ enabled: Bool) async {
        if enabled {
            let granted = await NotificationManager.requestAuthorization()
            await MainActor.run {
                routine.notificationsEnabled = granted
                notificationPermissionDenied = !granted
            }
            try? modelContext.save()
            if granted {
                await NotificationManager.schedule(routine: routine)
            }
        } else {
            await MainActor.run {
                routine.notificationsEnabled = false
                notificationPermissionDenied = false
            }
            NotificationManager.cancel(routineID: routine.id)
            try? modelContext.save()
        }
    }
}

// MARK: - Sub-sheets

/// Editor for an instance's per-routine start date. Setting a date hides
/// the habit from this routine until then; clearing it makes the habit
/// active immediately (subject to the habit's own phase-in, if any).
private struct InstanceStartDateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var instance: HabitInstance

    @State private var scheduled: Bool = false
    @State private var startDate: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let habit = instance.habit {
                        HStack(spacing: 12) {
                            Image(systemName: habit.iconSystemName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(habit.color)
                                .frame(width: 32, height: 32)
                                .background(habit.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.name).font(.subheadline.weight(.semibold))
                                Text(habit.displayCategory)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Pre-assign with start date", isOn: $scheduled)
                    if scheduled {
                        DatePicker("Start on", selection: $startDate, in: Date()..., displayedComponents: .date)
                    }
                } footer: {
                    Text("The habit will only appear in this routine starting on the chosen date. Other routines using this habit are unaffected.")
                }

                if let habitPhase = instance.habit?.phaseInDate, habitPhase > Date() {
                    Section {
                        Label(
                            "This habit is itself phased in on \(habitPhase.formatted(.dateTime.month().day())).",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let existing = instance.phaseInDate {
                    scheduled = true
                    startDate = existing
                } else {
                    scheduled = false
                    startDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        instance.phaseInDate = scheduled ? Calendar.current.startOfDay(for: startDate) : nil
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Pick which other weekdays should receive a copy of this routine.
private struct RoutineCopySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let routine: Routine

    @State private var selectedDays: Set<Int> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Weekday.allCases) { day in
                        dayRow(day)
                    }
                } header: {
                    Text("Copy to days")
                } footer: {
                    Text("A copy of this routine and its habit stack will appear on each selected day. Notifications must be turned on per copy.")
                }
            }
            .navigationTitle("Copy Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy") { performCopy() }
                        .fontWeight(.semibold)
                        .disabled(selectedDays.isEmpty)
                }
            }
        }
    }

    private func dayRow(_ day: Weekday) -> some View {
        let isSource = day.rawValue == routine.dayOfWeek
        let isSelected = selectedDays.contains(day.rawValue)
        return Button {
            guard !isSource else { return }
            if isSelected {
                selectedDays.remove(day.rawValue)
            } else {
                selectedDays.insert(day.rawValue)
            }
        } label: {
            HStack {
                Text(day.fullLabel)
                    .foregroundStyle(isSource ? .secondary : .primary)
                Spacer()
                if isSource {
                    Text("Source")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isSource)
    }

    private func performCopy() {
        for day in selectedDays {
            let copy = Routine(
                name: routine.name,
                iconSystemName: routine.iconSystemName,
                dayOfWeek: day,
                timeOfDay: routine.timeOfDay,
                sortOrder: routine.sortOrder,
                startHour: routine.startHour,
                startMinute: routine.startMinute,
                notificationsEnabled: false,
                overrideDate: nil
            )
            modelContext.insert(copy)
            for instance in routine.orderedHabits {
                guard let habit = instance.habit else { continue }
                let newInstance = HabitInstance(
                    habit: habit,
                    routine: copy,
                    sortOrder: instance.sortOrder,
                    phaseInDate: instance.phaseInDate
                )
                modelContext.insert(newInstance)
            }
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    HabitStackPreview()
}

@MainActor
private struct HabitStackPreview: View {
    var body: some View {
        let container = PreviewSupport.container
        let routine = (try? container.mainContext.fetch(FetchDescriptor<Routine>()))?.first
        return Group {
            if let routine {
                HabitStackView(routine: routine)
                    .modelContainer(container)
            } else {
                Text("No routine")
            }
        }
    }
}
