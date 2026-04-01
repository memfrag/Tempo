import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: SidebarItem = .today

    @State private var todayViewModel: TodayViewModel?
    @State private var entriesViewModel: EntriesViewModel?
    @State private var reportViewModel: ReportViewModel?
    @State private var calendarViewModel: CalendarViewModel?
    @State private var projectsViewModel: ProjectsViewModel?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            Group {
                switch selection {
                case .today:
                    if let todayViewModel {
                        TodayDashboard(todayViewModel: todayViewModel)
                    }
                case .entries:
                    if let entriesViewModel {
                        EntriesView(entriesViewModel: entriesViewModel)
                    }
                case .reports:
                    if let reportViewModel {
                        ReportView(reportViewModel: reportViewModel)
                    }
                case .calendar:
                    if let calendarViewModel {
                        CalendarView(calendarViewModel: calendarViewModel)
                    }
                case .projects:
                    if let projectsViewModel {
                        ProjectsView(projectsViewModel: projectsViewModel)
                    }
                }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { Task { await refreshAllViews() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .onAppear { initializeViewModels() }
        .onChange(of: appState.isAuthenticated) { initializeViewModels() }
    }

    private func refreshAllViews() async {
        try? await appState.loadProjects()
        async let today: () = todayViewModel?.loadAll() ?? ()
        async let entries: () = entriesViewModel?.loadEntries() ?? ()
        async let report: () = reportViewModel?.loadWeek() ?? ()
        async let calendar: () = calendarViewModel?.loadInitialRange() ?? ()
        async let projects: () = projectsViewModel?.loadStats() ?? ()
        _ = await (today, entries, report, calendar, projects)
    }

    private func initializeViewModels() {
        guard appState.isAuthenticated else { return }
        if todayViewModel == nil { todayViewModel = TodayViewModel(appState: appState) }
        if entriesViewModel == nil { entriesViewModel = EntriesViewModel(appState: appState) }
        if reportViewModel == nil { reportViewModel = ReportViewModel(appState: appState) }
        if calendarViewModel == nil { calendarViewModel = CalendarViewModel(appState: appState) }
        if projectsViewModel == nil { projectsViewModel = ProjectsViewModel(appState: appState) }
    }
}
