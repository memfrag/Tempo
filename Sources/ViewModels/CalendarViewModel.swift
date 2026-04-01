import SwiftUI

@MainActor @Observable
final class CalendarViewModel {
    var entriesByDate: [String: [NokoEntry]] = [:]
    var isLoading = false
    var error: String?

    private var loadedRangeStart: Date
    private var loadedRangeEnd: Date
    private var appState: AppState

    init(appState: AppState) {
        self.appState = appState
        let calendar = Calendar.current
        let today = Date()
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        self.loadedRangeStart = calendar.date(byAdding: .month, value: -3, to: startOfCurrentMonth)!
        // End of current month
        var endMonth = calendar.date(byAdding: .month, value: 1, to: startOfCurrentMonth)!
        // If today's week spills into the next month, include that full month too
        let endOfWeek = calendar.date(byAdding: .day, value: 7 - calendar.component(.weekday, from: today), to: today)!
        if let endOfWeekMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: endOfWeek)),
           endOfWeekMonth >= endMonth {
            endMonth = calendar.date(byAdding: .month, value: 1, to: endOfWeekMonth)!
        }
        self.loadedRangeEnd = endMonth
    }

    var client: NokoClient? { appState.client }

    // MARK: - Calendar Grid Data

    /// Generate weeks for the loaded range
    var weeks: [[CalendarDay]] {
        let cal = Calendar.current
        // Find the Monday at or before loadedRangeStart
        var start = loadedRangeStart
        while cal.component(.weekday, from: start) != 2 { // 2 = Monday
            start = cal.date(byAdding: .day, value: -1, to: start)!
        }

        // Find the Sunday at or after loadedRangeEnd
        var end = loadedRangeEnd
        while cal.component(.weekday, from: end) != 1 { // 1 = Sunday
            end = cal.date(byAdding: .day, value: 1, to: end)!
        }

        var weeks: [[CalendarDay]] = []
        var current = start
        while current <= end {
            var week: [CalendarDay] = []
            for _ in 0..<7 {
                let dateStr = TimeFormatter.apiDateString(current)
                let entries = entriesByDate[dateStr] ?? []
                let totalMinutes = entries.reduce(0) { $0 + $1.minutes }
                week.append(CalendarDay(
                    date: current,
                    dateString: dateStr,
                    entries: entries,
                    totalMinutes: totalMinutes,
                    isToday: cal.isDateInToday(current),
                    isWeekend: cal.isDateInWeekend(current)
                ))
                current = cal.date(byAdding: .day, value: 1, to: current)!
            }
            weeks.append(week)
        }
        return weeks
    }

    /// Month banners: returns (weekIndex, monthLabel) pairs where a new month starts
    func monthBannerForWeek(_ week: [CalendarDay]) -> String? {
        // Show banner if the first day of this week is day 1, or if
        // the week contains the first day of a month
        let cal = Calendar.current
        for day in week {
            if cal.component(.day, from: day.date) == 1 {
                let f = DateFormatter()
                f.dateFormat = "MMMM yyyy"
                return f.string(from: day.date)
            }
        }
        // Also show for the very first week
        if let first = week.first, first.date <= loadedRangeStart {
            let f = DateFormatter()
            f.dateFormat = "MMMM yyyy"
            return f.string(from: first.date)
        }
        return nil
    }

    func totalMinutesForMonth(containing date: Date) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return entriesByDate
            .filter { dateString, _ in
                guard let parsed = TimeFormatter.parseAPIDate(dateString) else { return false }
                return calendar.component(.year, from: parsed) == year
                    && calendar.component(.month, from: parsed) == month
            }
            .values
            .flatMap { $0 }
            .reduce(0) { $0 + $1.minutes }
    }

    // MARK: - Loading

    func loadInitialRange() async {
        guard let client else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let entries = try await client.allEntries(from: loadedRangeStart, to: loadedRangeEnd, userId: appState.currentUserId)
            var byDate: [String: [NokoEntry]] = [:]
            for entry in entries {
                byDate[entry.date, default: []].append(entry)
            }
            self.entriesByDate = byDate
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadEarlierMonth() async {
        guard let client else { return }
        let cal = Calendar.current
        let newStart = cal.date(byAdding: .month, value: -1, to: loadedRangeStart)!
        do {
            let entries = try await client.allEntries(from: newStart, to: loadedRangeStart, userId: appState.currentUserId)
            for entry in entries {
                entriesByDate[entry.date, default: []].append(entry)
            }
            loadedRangeStart = newStart
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadLaterMonth() async {
        guard let client else { return }
        let cal = Calendar.current
        let newEnd = cal.date(byAdding: .month, value: 1, to: loadedRangeEnd)!
        do {
            let entries = try await client.allEntries(from: loadedRangeEnd, to: newEnd, userId: appState.currentUserId)
            for entry in entries {
                entriesByDate[entry.date, default: []].append(entry)
            }
            loadedRangeEnd = newEnd
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let dateString: String
    let entries: [NokoEntry]
    let totalMinutes: Int
    let isToday: Bool
    let isWeekend: Bool

    var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var formattedTotal: String? {
        guard totalMinutes > 0 else { return nil }
        return TimeFormatter.minutesToDisplay(totalMinutes)
    }
}
