//
//  DayPicker.swift
//  AtomicMe
//

import SwiftUI

/// Swipeable week-by-week strip backed by a paged TabView. Lets you
/// browse far into the future or past instead of only the current week.
struct WeekStripPager: View {
    @Binding var selectedDate: Date

    /// How many weeks before/after the current week the pager spans.
    private let weekRadius: Int = 104

    @State private var weekOffset: Int = 0
    @State private var showingDatePicker: Bool = false

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 10) {
            controlBar

            TabView(selection: $weekOffset) {
                ForEach(-weekRadius...weekRadius, id: \.self) { offset in
                    DayStrip(
                        selectedDate: $selectedDate,
                        weekDates: weekDates(for: offset)
                    )
                    .padding(.horizontal, 4)
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 68)
        }
        .onAppear {
            weekOffset = weekOffset(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newValue in
            let target = weekOffset(for: newValue)
            if target != weekOffset {
                withAnimation { weekOffset = target }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation { weekOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemBackground), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            VStack(spacing: 0) {
                Text(monthLabel)
                    .font(.subheadline.weight(.semibold))
                Text(weekRangeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button {
                showingDatePicker = true
            } label: {
                Image(systemName: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemBackground), in: Circle())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation { weekOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemBackground), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private var monthLabel: String {
        let date = anchorDate(for: weekOffset)
        return date.formatted(.dateTime.month(.wide).year())
    }

    private var weekRangeLabel: String {
        let dates = weekDates(for: weekOffset)
        guard let first = dates.first, let last = dates.last else { return "" }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func anchorDate(for offset: Int) -> Date {
        calendar.date(byAdding: .weekOfYear, value: offset, to: Date()) ?? Date()
    }

    private func weekDates(for offset: Int) -> [Date] {
        let weekDate = anchorDate(for: offset)
        let start = calendar.dateInterval(of: .weekOfYear, for: weekDate)?.start
            ?? calendar.startOfDay(for: weekDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Number of weeks between the current week and the week containing `date`.
    private func weekOffset(for date: Date) -> Int {
        let today = calendar.startOfDay(for: Date())
        let weekStartToday = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let weekStartTarget = calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.weekOfYear], from: weekStartToday, to: weekStartTarget)
        return diff.weekOfYear ?? 0
    }
}

/// One week's worth of day buttons.
struct DayStrip: View {
    @Binding var selectedDate: Date
    let weekDates: [Date]

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { date in
                dayButton(for: date)
            }
        }
    }

    @ViewBuilder
    private func dayButton(for date: Date) -> some View {
        let weekday = Weekday.from(date: date, calendar: calendar)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let dayNum = calendar.component(.day, from: date)

        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedDate = calendar.startOfDay(for: date)
            }
        } label: {
            VStack(spacing: 6) {
                Text(weekday.shortLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                Text("\(dayNum)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isToday && !isSelected ? Color.accentColor.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// Full-month calendar sheet used by the calendar button.
private struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    @State private var workingDate: Date = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    "Jump to date",
                    selection: $workingDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                Button {
                    workingDate = Calendar.current.startOfDay(for: Date())
                } label: {
                    Label("Jump to today", systemImage: "scope")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle("Pick a date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedDate = Calendar.current.startOfDay(for: workingDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { workingDate = selectedDate }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    StatefulPreview()
        .padding()
}

private struct StatefulPreview: View {
    @State private var date = Date()
    var body: some View {
        WeekStripPager(selectedDate: $date)
    }
}
