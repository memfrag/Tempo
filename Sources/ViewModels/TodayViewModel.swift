import SwiftUI

@MainActor @Observable
final class TodayViewModel {
    var todayEntries: [NokoEntry] = []
    var todayTotal: Int = 0
    var weekTotal: Double = 0
    var monthTotal: Double = 0
    var entryCount: Int = 0

    var isLoading = false
    var error: String?

    private var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var client: NokoClient? { appState.client }

    // MARK: - Loading

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        async let today: () = loadTodayEntries()
        async let week: () = loadWeekStats()
        async let month: () = loadMonthStats()
        _ = await (today, week, month)
    }

    func loadTodayEntries() async {
        guard let client else { return }
        do {
            let today = Date()
            let result = try await client.entries(from: today, to: today, userId: appState.currentUserId)
            self.todayEntries = result.entries
            self.todayTotal = result.entries.reduce(0) { $0 + $1.minutes }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadWeekStats() async {
        guard let client else { return }
        do {
            let calendar = Calendar.current
            let today = Date()
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
            let result = try await client.entries(from: weekStart, to: today, userId: appState.currentUserId)
            self.weekTotal = Double(result.entries.reduce(0) { $0 + $1.minutes }) / 60.0
        } catch {}
    }

    private func loadMonthStats() async {
        guard let client else { return }
        do {
            let calendar = Calendar.current
            let today = Date()
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            let result = try await client.allEntries(from: monthStart, to: today, userId: appState.currentUserId)
            self.monthTotal = Double(result.reduce(0) { $0 + $1.minutes }) / 60.0
            self.entryCount = result.count
        } catch {}
    }

    // MARK: - Create Entry

    func createEntry(date: Date, minutes: Int, projectId: Int?, description: String?) async {
        guard let client else { return }
        do {
            let entry = try await client.createEntry(
                date: date, minutes: minutes,
                projectId: projectId, description: description
            )
            self.todayEntries.insert(entry, at: 0)
            self.todayTotal += entry.minutes
            self.entryCount += 1
        } catch {
            self.error = error.localizedDescription
        }
    }
}
