//
//  ProgressTabView.swift
//  AtomicMe
//

import SwiftUI
import SwiftData
import Charts

/// Stats screen. Daily completion rate is computed the same way as the
/// Today tab — for each day we resolve what was scheduled (honoring
/// overrides and per-instance pre-assignments) and divide done by total.
struct ProgressTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Habit> { !$0.isArchived })
    private var allHabits: [Habit]
    @Query private var allRoutines: [Routine]
    @Query private var allOverrides: [DayOverride]

    private var calendar: Calendar { Calendar.current }
    private let windowDays: Int = 14

    private var windowDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<windowDays).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }

    /// (date, scheduled habit count, completed count) for each day in the window.
    private var dailyStats: [(date: Date, scheduled: Int, completed: Int)] {
        windowDates.map { date in
            let habits = DailyPlan.activeHabits(
                on: date,
                allRoutines: allRoutines,
                allOverrides: allOverrides
            )
            let completed = habits.filter { CompletionTracker.isCompleted(habit: $0, on: date) }.count
            return (date, habits.count, completed)
        }
    }

    /// Completion percentage per day. Days with nothing scheduled count as 0.
    private var dailyRates: [(date: Date, rate: Double)] {
        dailyStats.map { entry in
            let rate = entry.scheduled > 0 ? Double(entry.completed) / Double(entry.scheduled) : 0
            return (entry.date, rate)
        }
    }

    /// Average rate across days that actually had something scheduled.
    private var overallRate: Double {
        let scheduledDays = dailyStats.filter { $0.scheduled > 0 }
        guard !scheduledDays.isEmpty else { return 0 }
        let rates = scheduledDays.map { Double($0.completed) / Double($0.scheduled) }
        return rates.reduce(0, +) / Double(rates.count)
    }

    /// Per-habit: in how many of its scheduled days within the window was it completed.
    private var perHabitRates: [(habit: Habit, rate: Double, scheduled: Int)] {
        allHabits.compactMap { habit in
            var scheduled = 0
            var completed = 0
            for date in windowDates {
                let active = DailyPlan.activeHabits(
                    on: date,
                    allRoutines: allRoutines,
                    allOverrides: allOverrides
                )
                if active.contains(where: { $0.id == habit.id }) {
                    scheduled += 1
                    if CompletionTracker.isCompleted(habit: habit, on: date) {
                        completed += 1
                    }
                }
            }
            guard scheduled > 0 else { return nil }
            let rate = Double(completed) / Double(scheduled)
            return (habit, rate, scheduled)
        }
        .sorted { $0.rate > $1.rate }
    }

    /// Number of consecutive days (going back from today) where everything
    /// scheduled was completed. Days with nothing scheduled break the streak.
    private var currentStreak: Int {
        var streak = 0
        let today = calendar.startOfDay(for: Date())
        for offset in 0..<60 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let active = DailyPlan.activeHabits(
                on: date,
                allRoutines: allRoutines,
                allOverrides: allOverrides
            )
            // Don't count "today" as a missed day if there's still time to complete.
            if active.isEmpty {
                if offset == 0 { continue }
                break
            }
            let allDone = active.allSatisfy { CompletionTracker.isCompleted(habit: $0, on: date) }
            if allDone {
                streak += 1
            } else if offset == 0 {
                continue
            } else {
                break
            }
        }
        return streak
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    overallCard
                    trendChartCard
                    habitListCard
                }
                .padding(16)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Progress")
        }
    }

    private var overallCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Last \(windowDays) days")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(Int(overallRate * 100))%")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                Text("Average completion")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Label("\(currentStreak)", systemImage: "flame.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
                Text("Day streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily completion")
                .font(.subheadline.weight(.semibold))

            Chart {
                ForEach(dailyRates, id: \.date) { point in
                    AreaMark(
                        x: .value("Day", point.date),
                        y: .value("Rate", point.rate)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("Rate", point.rate)
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    PointMark(
                        x: .value("Day", point.date),
                        y: .value("Rate", point.rate)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(28)
                }
            }
            .chartYScale(domain: 0...1)
            .chartYAxis {
                AxisMarks(values: [0, 0.5, 1]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v * 100))%")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 180)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var habitListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habit Completion")
                .font(.subheadline.weight(.semibold))

            if perHabitRates.isEmpty {
                Text("No habits scheduled in the last \(windowDays) days yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(perHabitRates, id: \.habit.id) { entry in
                        habitProgressRow(
                            habit: entry.habit,
                            rate: entry.rate,
                            scheduled: entry.scheduled
                        )
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func habitProgressRow(habit: Habit, rate: Double, scheduled: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: habit.iconSystemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(habit.color)
                    .frame(width: 26, height: 26)
                    .background(habit.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 0) {
                    Text(habit.name)
                        .font(.subheadline.weight(.medium))
                    Text("\(scheduled) day\(scheduled == 1 ? "" : "s") scheduled")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(rate * 100))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: rate)
                .tint(habit.color)
        }
    }
}

#Preview {
    ProgressTabView()
        .modelContainer(PreviewSupport.container)
}
