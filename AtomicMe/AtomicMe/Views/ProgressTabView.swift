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
    private let maxWindowDays: Int = 14

    private var today: Date { calendar.startOfDay(for: Date()) }

    /// The earliest completion logged across every habit. Used to grow the
    /// overall window from "since you started" into a rolling 14-day window
    /// once enough history exists.
    private var firstEverCompletionDay: Date? {
        let earliest = allHabits.flatMap { $0.completions ?? [] }.map { $0.date }.min()
        return earliest.map { calendar.startOfDay(for: $0) }
    }

    /// Dates included in the overall stats. Starts at the first ever
    /// completion and grows until it caps at `maxWindowDays`, after which
    /// it slides forward.
    private var windowDates: [Date] {
        let start = effectiveWindowStart(earliestCompletion: firstEverCompletionDay) ?? today
        return datesFrom(start, through: today)
    }

    /// (date, scheduled instance count, completed instance count) for each
    /// day in the window. Counts duplicates when a habit appears in more
    /// than one routine that day.
    private var dailyStats: [(date: Date, scheduled: Int, completed: Int)] {
        windowDates.map { date in
            let instances = DailyPlan.activeInstances(
                on: date,
                allRoutines: allRoutines,
                allOverrides: allOverrides
            )
            let completed = instances.filter {
                CompletionTracker.isCompleted(instance: $0, on: date)
            }.count
            return (date, instances.count, completed)
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

    /// Per-habit: instances completed / instances scheduled across that
    /// habit's own dynamic window (from its first completion until today,
    /// capped at the rolling 14 days). Habits with no completions yet are
    /// omitted — we have nothing to compute against.
    private var perHabitRates: [(habit: Habit, rate: Double, dates: [Date])] {
        allHabits.compactMap { habit in
            let earliest = (habit.completions ?? []).map { $0.date }.min()
                .map { calendar.startOfDay(for: $0) }
            guard let start = effectiveWindowStart(earliestCompletion: earliest) else { return nil }
            let dates = datesFrom(start, through: today)
            var scheduled = 0
            var completed = 0
            for date in dates {
                let instances = DailyPlan.activeInstances(
                    on: date,
                    allRoutines: allRoutines,
                    allOverrides: allOverrides
                ).filter { $0.habit?.id == habit.id }
                scheduled += instances.count
                completed += instances.filter {
                    CompletionTracker.isCompleted(instance: $0, on: date)
                }.count
            }
            guard scheduled > 0 else { return nil }
            let rate = Double(completed) / Double(scheduled)
            return (habit, rate, dates)
        }
        .sorted { $0.rate > $1.rate }
    }

    /// Number of consecutive days (going back from today) where every
    /// scheduled instance was completed. Days with nothing scheduled break
    /// the streak.
    private var currentStreak: Int {
        var streak = 0
        for offset in 0..<60 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let instances = DailyPlan.activeInstances(
                on: date,
                allRoutines: allRoutines,
                allOverrides: allOverrides
            )
            // Don't count "today" as a missed day if there's still time to complete.
            if instances.isEmpty {
                if offset == 0 { continue }
                break
            }
            let allDone = instances.allSatisfy {
                CompletionTracker.isCompleted(instance: $0, on: date)
            }
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

    /// Returns the start of the window: the later of (earliestCompletion)
    /// and (today − 13 days). nil when there are no completions yet.
    private func effectiveWindowStart(earliestCompletion: Date?) -> Date? {
        guard let earliest = earliestCompletion else { return nil }
        guard let cutoff = calendar.date(byAdding: .day, value: -(maxWindowDays - 1), to: today) else {
            return earliest
        }
        return max(earliest, cutoff)
    }

    private func datesFrom(_ start: Date, through end: Date) -> [Date] {
        var dates: [Date] = []
        var cursor = start
        while cursor <= end {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates
    }

    /// Caption shown next to the overall stat: "Since Jun 18" while ramping
    /// up, "Last 14 days" once the rolling window is full.
    private var windowLabel: String {
        guard !windowDates.isEmpty else { return "No completions yet" }
        if windowDates.count >= maxWindowDays {
            return "Last \(maxWindowDays) days"
        }
        guard let start = windowDates.first else { return "Last \(windowDates.count) days" }
        return "Since \(start.formatted(.dateTime.month(.abbreviated).day()))"
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
                Text(windowLabel)
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
                Text("Complete a habit to start tracking its progress.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(perHabitRates, id: \.habit.id) { entry in
                        habitProgressRow(
                            habit: entry.habit,
                            rate: entry.rate,
                            dates: entry.dates
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

    private func habitProgressRow(habit: Habit, rate: Double, dates: [Date]) -> some View {
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
                    Text(habitRowSubtitle(for: dates))
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

    private func habitRowSubtitle(for dates: [Date]) -> String {
        if dates.count >= maxWindowDays {
            return "Last \(maxWindowDays) days"
        }
        guard let start = dates.first else { return "" }
        return "Since \(start.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

#Preview {
    ProgressTabView()
        .modelContainer(PreviewSupport.container)
}
