import SwiftUI

@MainActor @Observable
final class ReportViewModel {
    var weekEntries: [NokoEntry] = []
    var weekStart: Date
    var isLoading = false
    var error: String?

    private var appState: AppState

    init(appState: AppState) {
        self.appState = appState
        let cal = Calendar.current
        self.weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
    }

    var client: NokoClient? { appState.client }

    var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!
    }

    var weekLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let end = f.string(from: weekEnd)
        let start = f.string(from: weekStart)
        let yearF = DateFormatter()
        yearF.dateFormat = ", yyyy"
        return "\(start) – \(end)\(yearF.string(from: weekEnd))"
    }

    var totalMinutes: Int {
        weekEntries.reduce(0) { $0 + $1.minutes }
    }

    var totalHours: Double {
        Double(totalMinutes) / 60.0
    }

    var dailyAverage: Double {
        let workdays = max(1, daysWithEntries)
        return totalHours / Double(workdays)
    }

    var daysWithEntries: Int {
        Set(weekEntries.map(\.date)).count
    }

    /// Entries per day of the week (Mon=0 ... Sun=6)
    var dailyBreakdown: [DayData] {
        let cal = Calendar.current
        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: weekStart)!
            let dateStr = TimeFormatter.apiDateString(date)
            let dayEntries = weekEntries.filter { $0.date == dateStr }
            let minutes = dayEntries.reduce(0) { $0 + $1.minutes }
            let f = DateFormatter()
            f.dateFormat = "EEE"
            let isToday = cal.isDateInToday(date)
            return DayData(
                label: f.string(from: date),
                date: date,
                minutes: minutes,
                entries: dayEntries,
                isToday: isToday
            )
        }
    }

    /// Project breakdown sorted by hours descending
    var projectBreakdown: [ProjectData] {
        let grouped = Dictionary(grouping: weekEntries) { $0.project?.id ?? 0 }
        return grouped.map { _, entries in
            let minutes = entries.reduce(0) { $0 + $1.minutes }
            let project = entries.first?.project
            return ProjectData(
                project: project,
                minutes: minutes,
                percentage: totalMinutes > 0 ? Double(minutes) / Double(totalMinutes) : 0
            )
        }
        .sorted { $0.minutes > $1.minutes }
    }

    // MARK: - Loading

    func loadWeek() async {
        guard let client else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let sidebarProjectIds = appState.sidebarProjectIds.isEmpty ? nil : appState.sidebarProjectIds
            let result = try await client.allEntries(from: weekStart, to: weekEnd, projectIds: sidebarProjectIds, userId: appState.currentUserId)
            weekEntries = result
        } catch {
            self.error = error.localizedDescription
        }
    }

    func previousWeek() {
        weekStart = Calendar.current.date(byAdding: .day, value: -7, to: weekStart)!
        Task { await loadWeek() }
    }

    func nextWeek() {
        weekStart = Calendar.current.date(byAdding: .day, value: 7, to: weekStart)!
        Task { await loadWeek() }
    }
}

struct DayData: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let minutes: Int
    let entries: [NokoEntry]
    let isToday: Bool

    var hours: Double { Double(minutes) / 60.0 }

    /// Entries grouped by project for stacked bar
    var projectSegments: [(project: ProjectRef?, minutes: Int)] {
        let grouped = Dictionary(grouping: entries) { $0.project?.id ?? 0 }
        return grouped.map { _, entries in
            (project: entries.first?.project, minutes: entries.reduce(0) { $0 + $1.minutes })
        }.sorted { $0.minutes > $1.minutes }
    }
}

struct ProjectData: Identifiable {
    let id = UUID()
    let project: ProjectRef?
    let minutes: Int
    let percentage: Double

    var hours: Double { Double(minutes) / 60.0 }
    var name: String { project?.name ?? "No Project" }
    var color: Color { project?.swiftUIColor ?? .gray }
}
