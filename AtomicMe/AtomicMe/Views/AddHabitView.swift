//
//  AddHabitView.swift
//  AtomicMe
//

import SwiftUI
import SwiftData

/// Library picker for adding a habit to a routine. Pick from suggested
/// templates, re-use an existing habit, or create a custom one.
/// Mirrors the third tile in the mockup.
struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let routine: Routine

    @Query private var allHabits: [Habit]
    @Query(sort: [SortDescriptor(\CustomCategory.createdAt)])
    private var customCategories: [CustomCategory]

    @State private var searchText: String = ""
    @State private var scheduleStart: Bool = false
    @State private var scheduledStartDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var showingCustomSheet: Bool = false
    @State private var customName: String = ""
    @State private var customCategory: HabitCategory = .wellness
    @State private var selectedCustomCategory: CustomCategory?
    @State private var customIcon: String = "checkmark.circle.fill"
    @State private var customPhaseIn: Bool = false
    @State private var customPhaseDate: Date = Date()
    @State private var customHasTodoList: Bool = false
    @State private var showingIconSheet: Bool = false
    @State private var showingNewCategorySheet: Bool = false

    /// Color preview for the new habit — built-in category tint, or the
    /// selected/placeholder custom category color.
    private var currentTint: Color {
        if customCategory == .custom {
            return selectedCustomCategory?.color ?? .gray
        }
        return customCategory.tint
    }

    private var filteredLibrary: [HabitTemplate] {
        if searchText.isEmpty { return HabitLibrary.all }
        return HabitLibrary.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var existingActiveHabits: [Habit] {
        allHabits
            .filter { !$0.isArchived }
            .filter { habit in
                if searchText.isEmpty { return true }
                return habit.name.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.name < $1.name }
    }

    private var routineHabitIDs: Set<UUID> {
        Set((routine.habitInstances ?? []).compactMap { $0.habit?.id })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Pre-assign with start date", isOn: $scheduleStart)
                    if scheduleStart {
                        DatePicker("Start on", selection: $scheduledStartDate, in: Date()..., displayedComponents: .date)
                    }
                } footer: {
                    Text(scheduleStart
                         ? "Habits you add now stay hidden from this routine until \(scheduledStartDate.formatted(.dateTime.month().day()))."
                         : "Turn on to pre-assign habits that should appear later. Great for the next habit on your roadmap.")
                }

                if !existingActiveHabits.isEmpty {
                    Section("Your habits") {
                        ForEach(existingActiveHabits, id: \.id) { habit in
                            existingRow(habit: habit)
                        }
                    }
                }

                ForEach(HabitLibrary.grouped(), id: \.0) { category, templates in
                    let visible = templates.filter { template in
                        searchText.isEmpty || template.name.localizedCaseInsensitiveContains(searchText)
                    }
                    if !visible.isEmpty {
                        Section(category.rawValue) {
                            ForEach(visible) { template in
                                templateRow(template: template)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showingCustomSheet = true
                    } label: {
                        Label("Create Your Own", systemImage: "plus.circle.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search habits")
            .navigationTitle("Add Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCustomSheet) {
                customHabitSheet
            }
        }
    }

    private func existingRow(habit: Habit) -> some View {
        let alreadyAdded = routineHabitIDs.contains(habit.id)
        return Button {
            if !alreadyAdded {
                add(habit: habit)
            }
        } label: {
            HStack {
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
                Spacer()
                if alreadyAdded {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .disabled(alreadyAdded)
    }

    private func templateRow(template: HabitTemplate) -> some View {
        Button {
            addNewHabit(from: template)
        } label: {
            HStack {
                Image(systemName: template.iconSystemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: template.colorHex) ?? .green)
                    .frame(width: 32, height: 32)
                    .background((Color(hex: template.colorHex) ?? .green).opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 8))
                Text(template.name).font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private func add(habit: Habit) {
        let nextOrder = ((routine.habitInstances ?? []).map { $0.sortOrder }.max() ?? -1) + 1
        let instance = HabitInstance(
            habit: habit,
            routine: routine,
            sortOrder: nextOrder,
            phaseInDate: scheduleStart ? Calendar.current.startOfDay(for: scheduledStartDate) : nil
        )
        modelContext.insert(instance)
        try? modelContext.save()
        dismiss()
    }

    private func addNewHabit(from template: HabitTemplate) {
        let habit = Habit(
            name: template.name,
            iconSystemName: template.iconSystemName,
            colorHex: template.colorHex,
            category: template.category
        )
        modelContext.insert(habit)
        add(habit: habit)
    }

    // MARK: - Custom habit sheet

    private var customHabitSheet: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Habit name", text: $customName)
                }
                Section("Category") {
                    Picker("Category", selection: $customCategory) {
                        ForEach(HabitCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.iconSystemName)
                                .foregroundStyle(category.tint)
                                .tag(category)
                        }
                    }
                    .onChange(of: customCategory) { _, newValue in
                        customIcon = newValue.iconSystemName
                        if newValue != .custom {
                            selectedCustomCategory = nil
                        }
                    }
                }
                if customCategory == .custom {
                    Section {
                        ForEach(customCategories) { cc in
                            categoryRow(cc)
                        }
                        Button {
                            showingNewCategorySheet = true
                        } label: {
                            Label("New category…", systemImage: "plus.circle.fill")
                        }
                    } header: {
                        Text("Custom category")
                    } footer: {
                        Text("Categories remember their color. Habits sharing a category share its tint.")
                    }
                }
                Section("Icon") {
                    Button {
                        showingIconSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(currentTint.opacity(0.18))
                                Image(systemName: customIcon.isEmpty ? "questionmark" : customIcon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(currentTint)
                            }
                            .frame(width: 40, height: 40)
                            VStack(alignment: .leading) {
                                Text("Pick from library")
                                    .foregroundStyle(.primary)
                                Text(customIcon)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Section {
                    Toggle("Phase in later", isOn: $customPhaseIn)
                    if customPhaseIn {
                        DatePicker("Start on", selection: $customPhaseDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("Phasing in keeps the habit out of your routine until the chosen date. Great for the next habit on your roadmap.")
                }

                Section {
                    Toggle("Attach a todo list", isOn: $customHasTodoList)
                } footer: {
                    Text("Adds a list icon on this habit so you can jot down todos to work on during it (e.g. \"Todo Time\").")
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCustomSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        createCustom()
                    }
                    .fontWeight(.semibold)
                    .disabled(
                        customName.trimmingCharacters(in: .whitespaces).isEmpty ||
                        customIcon.trimmingCharacters(in: .whitespaces).isEmpty ||
                        (customCategory == .custom && selectedCustomCategory == nil)
                    )
                }
            }
            .sheet(isPresented: $showingIconSheet) {
                IconPickerSheet(selectedIcon: $customIcon, tint: currentTint)
            }
            .sheet(isPresented: $showingNewCategorySheet) {
                NewCategorySheet { created in
                    selectedCustomCategory = created
                }
            }
        }
    }

    private func categoryRow(_ cc: CustomCategory) -> some View {
        let isSelected = selectedCustomCategory?.id == cc.id
        return Button {
            selectedCustomCategory = cc
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(cc.color.opacity(0.18))
                    Image(systemName: cc.iconSystemName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(cc.color)
                }
                .frame(width: 28, height: 28)
                Text(cc.name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func createCustom() {
        let name = customName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        // For Custom category, must have a selected CustomCategory.
        if customCategory == .custom, selectedCustomCategory == nil { return }
        let habit = Habit(
            name: name,
            iconSystemName: customIcon.trimmingCharacters(in: .whitespaces),
            colorHex: "#8E8E93",
            category: customCategory,
            customCategory: customCategory == .custom ? selectedCustomCategory : nil,
            customCategoryName: selectedCustomCategory?.name ?? "",
            phaseInDate: customPhaseIn ? customPhaseDate : nil,
            hasTodoList: customHasTodoList
        )
        modelContext.insert(habit)
        showingCustomSheet = false
        add(habit: habit)
    }
}

/// Lightweight form that creates a CustomCategory and hands it back via callback.
struct NewCategorySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var onCreated: (CustomCategory) -> Void

    @State private var name: String = ""
    @State private var colorHex: String = "#8E8E93"
    @State private var iconSystemName: String = "sparkles"
    @State private var showingIconSheet: Bool = false

    private let colorColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)

    private var tint: Color { Color(hex: colorHex) ?? .gray }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Hobby, Study, Family", text: $name)
                }
                Section("Color") {
                    LazyVGrid(columns: colorColumns, spacing: 12) {
                        ForEach(IconLibrary.palette, id: \.self) { hex in
                            let color = Color(hex: hex) ?? .gray
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                Color.primary.opacity(colorHex == hex ? 0.85 : 0),
                                                lineWidth: 2.5
                                            )
                                            .padding(2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Icon") {
                    Button {
                        showingIconSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(tint.opacity(0.18))
                                Image(systemName: iconSystemName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(tint)
                            }
                            .frame(width: 36, height: 36)
                            Text("Pick an icon")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingIconSheet) {
                IconPickerSheet(selectedIcon: $iconSystemName, tint: tint)
            }
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let category = CustomCategory(name: trimmed, colorHex: colorHex, iconSystemName: iconSystemName)
        modelContext.insert(category)
        try? modelContext.save()
        onCreated(category)
        dismiss()
    }
}

#Preview {
    AddHabitPreview()
}

@MainActor
private struct AddHabitPreview: View {
    var body: some View {
        let container = PreviewSupport.container
        let routine = (try? container.mainContext.fetch(FetchDescriptor<Routine>()))?.first
        return Group {
            if let routine {
                AddHabitView(routine: routine)
                    .modelContainer(container)
            } else {
                Text("No routine available")
            }
        }
    }
}
