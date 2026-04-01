import SwiftUI

@MainActor @Observable
final class ProjectsViewModel {
    var projectStats: [ProjectStat] = []
    var isLoading = false
    var error: String?

    private var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var client: NokoClient? { appState.client }

    func loadStats() async {
        guard let client else { return }
        isLoading = true
        defer { isLoading = false }

        let cal = Calendar.current
        let today = Date()
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today))!

        do {
            let weekEntries = try await client.allEntries(from: weekStart, to: today, userId: appState.currentUserId)
            let monthEntries = try await client.allEntries(from: monthStart, to: today, userId: appState.currentUserId)

            let projects = appState.projects
            var stats: [ProjectStat] = []

            for project in projects {
                let weekMins = weekEntries
                    .filter { $0.project?.id == project.id }
                    .reduce(0) { $0 + $1.minutes }
                let monthMins = monthEntries
                    .filter { $0.project?.id == project.id }
                    .reduce(0) { $0 + $1.minutes }

                if weekMins > 0 || monthMins > 0 {
                    stats.append(ProjectStat(
                        project: project,
                        weekMinutes: weekMins,
                        monthMinutes: monthMins
                    ))
                }
            }

            self.projectStats = stats.sorted { $0.monthMinutes > $1.monthMinutes }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ProjectStat: Identifiable {
    var id: Int { project.id }
    let project: NokoProject
    let weekMinutes: Int
    let monthMinutes: Int

    var weekHours: String { TimeFormatter.minutesToDisplay(weekMinutes) }
    var monthHours: String { TimeFormatter.minutesToDisplay(monthMinutes) }
}
