//
//  RoadmapView.swift
//  AtomicMe
//

import SwiftUI
import SwiftData

/// Phase-in timeline: shows habits already active, then upcoming
/// phased-in habits in chronological order. Mirrors the sixth tile.
struct RoadmapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Habit> { !$0.isArchived })
    private var allHabits: [Habit]

    @State private var editingHabit: Habit?
    @State private var showingNewHabitSheet: Bool = false

    private var activeHabits: [Habit] {
        allHabits.filter { $0.isPhasedIn }.sorted { $0.name < $1.name }
    }

    private var upcomingHabits: [Habit] {
        allHabits
            .filter { !$0.isPhasedIn }
            .sorted { ($0.phaseInDate ?? .distantFuture) < ($1.phaseInDate ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    sectionTitle("Active now", count: activeHabits.count)
                    activeList
                    sectionTitle("Coming up", count: upcomingHabits.count)
                    upcomingList
                }
                .padding(16)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Habit Roadmap")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewHabitSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingHabit) { habit in
                PhaseInEditorSheet(habit: habit)
            }
            .sheet(isPresented: $showingNewHabitSheet) {
                NewRoadmapHabitSheet()
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Phase in habits at the right time")
                .font(.headline)
            Text("Schedule new habits ahead of time. Atomic Me holds them off your daily stack until they're ready to start.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
    }

    private func sectionTitle(_ text: String, count: Int) -> some View {
        HStack {
            Text(text)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var activeList: some View {
        VStack(spacing: 0) {
            if activeHabits.isEmpty {
                emptyRow(text: "No active habits yet — add one to get started.")
            } else {
                ForEach(activeHabits, id: \.id) { habit in
                    roadmapRow(habit: habit, isActive: true)
                    if habit.id != activeHabits.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var upcomingList: some View {
        VStack(spacing: 0) {
            if upcomingHabits.isEmpty {
                emptyRow(text: "Nothing queued. Tap + to plan your next habit.")
            } else {
                ForEach(upcomingHabits, id: \.id) { habit in
                    roadmapRow(habit: habit, isActive: false)
                    if habit.id != upcomingHabits.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func roadmapRow(habit: Habit, isActive: Bool) -> some View {
        Button {
            editingHabit = habit
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(habit.color.opacity(0.15))
                    Image(systemName: habit.iconSystemName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(habit.color)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if isActive {
                        Text("Active · \(habit.displayCategory)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let date = habit.phaseInDate {
                        Text("Starts \(date.formatted(.dateTime.month().day())) · \(daysAway(date)) days away")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                Image(systemName: isActive ? "checkmark.circle.fill" : "calendar.badge.clock")
                    .foregroundStyle(isActive ? Color.accentColor : Color.orange)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
    }

    private func emptyRow(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
    }

    private func daysAway(_ date: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: target).day ?? 0
    }
}

/// Adjusts a habit's phase-in date or makes it active immediately.
private struct PhaseInEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var habit: Habit
    @State private var phaseIn: Bool
    @State private var phaseDate: Date

    init(habit: Habit) {
        self._habit = Bindable(habit)
        let hasPhase = habit.phaseInDate != nil
        self._phaseIn = State(initialValue: hasPhase)
        self._phaseDate = State(initialValue: habit.phaseInDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: habit.iconSystemName)
                            .font(.title3)
                            .foregroundStyle(habit.color)
                            .frame(width: 32, height: 32)
                            .background(habit.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading) {
                            Text(habit.name).font(.headline)
                            Text(habit.displayCategory)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Toggle("Phase in later", isOn: $phaseIn)
                    if phaseIn {
                        DatePicker("Start on", selection: $phaseDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("The habit will only count toward your routines starting on this date.")
                }

                Section {
                    Toggle("Attach a todo list", isOn: $habit.hasTodoList)
                } footer: {
                    Text("Adds a list icon on this habit for jotting down todos to work on during it.")
                }

                Section {
                    Button(role: .destructive) {
                        habit.isArchived = true
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        Label("Archive habit", systemImage: "archivebox")
                    }
                }
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        habit.phaseInDate = phaseIn ? phaseDate : nil
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

/// Add a habit straight onto the roadmap (without picking a routine yet).
private struct NewRoadmapHabitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\CustomCategory.createdAt)])
    private var customCategories: [CustomCategory]

    @State private var name: String = ""
    @State private var category: HabitCategory = .wellness
    @State private var selectedCustomCategory: CustomCategory?
    @State private var icon: String = "checkmark.circle.fill"
    @State private var phaseIn: Bool = true
    @State private var phaseDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var hasTodoList: Bool = false
    @State private var showingIconSheet: Bool = false
    @State private var showingNewCategorySheet: Bool = false

    private var currentTint: Color {
        if category == .custom {
            return selectedCustomCategory?.color ?? .gray
        }
        return category.tint
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Habit name", text: $name)
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(HabitCategory.allCases) { categoryCase in
                            Label(categoryCase.rawValue, systemImage: categoryCase.iconSystemName)
                                .foregroundStyle(categoryCase.tint)
                                .tag(categoryCase)
                        }
                    }
                    .onChange(of: category) { _, newValue in
                        icon = newValue.iconSystemName
                        if newValue != .custom {
                            selectedCustomCategory = nil
                        }
                    }
                }
                if category == .custom {
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
                                Image(systemName: icon.isEmpty ? "questionmark" : icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(currentTint)
                            }
                            .frame(width: 40, height: 40)
                            VStack(alignment: .leading) {
                                Text("Pick from library")
                                    .foregroundStyle(.primary)
                                Text(icon)
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
                    Toggle("Phase in later", isOn: $phaseIn)
                    if phaseIn {
                        DatePicker("Start on", selection: $phaseDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("You can attach this habit to a routine later from the Today tab.")
                }

                Section {
                    Toggle("Attach a todo list", isOn: $hasTodoList)
                } footer: {
                    Text("Adds a list icon on this habit for jotting down todos to work on during it.")
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        if category == .custom, selectedCustomCategory == nil { return }
                        let habit = Habit(
                            name: trimmed,
                            iconSystemName: icon.trimmingCharacters(in: .whitespaces),
                            colorHex: "#8E8E93",
                            category: category,
                            customCategory: category == .custom ? selectedCustomCategory : nil,
                            customCategoryName: selectedCustomCategory?.name ?? "",
                            phaseInDate: phaseIn ? phaseDate : nil,
                            hasTodoList: hasTodoList
                        )
                        modelContext.insert(habit)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(
                        name.trimmingCharacters(in: .whitespaces).isEmpty ||
                        (category == .custom && selectedCustomCategory == nil)
                    )
                }
            }
            .sheet(isPresented: $showingIconSheet) {
                IconPickerSheet(selectedIcon: $icon, tint: currentTint)
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
                Text(cc.name).foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func hex(for color: Color) -> String {
        switch color {
        case .orange:  return "#FF9500"
        case .purple:  return "#AF52DE"
        case .pink:    return "#FF2D55"
        case .blue:    return "#0A84FF"
        case .green:   return "#34C759"
        case .mint:    return "#30D158"
        default:       return "#8E8E93"
        }
    }
}

#Preview {
    RoadmapView()
        .modelContainer(PreviewSupport.container)
}
