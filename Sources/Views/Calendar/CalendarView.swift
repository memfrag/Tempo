import SwiftUI

struct CalendarView: View {
    @Bindable var calendarViewModel: CalendarViewModel
    @Environment(AppState.self) private var appState
    @State private var scrollProxy: ScrollViewProxy?
    @AppStorage("calendarShowWeekends") private var showWeekends = true
    @State private var selectedDay: CalendarDay?

    private var dayLabels: [String] {
        showWeekends ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                     : ["Mon", "Tue", "Wed", "Thu", "Fri"]
    }

    var body: some View {
        HStack(spacing: 0) {
            // Calendar grid
            VStack(spacing: 0) {
                // Weekday headers
                HStack(spacing: 0) {
                    ForEach(dayLabels, id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 0.25)
                .background(.bar)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.separator)
                        .frame(height: 0.5)
                }

                // Grid
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(calendarViewModel.weeks.enumerated()), id: \.offset) { weekIndex, week in
                                let visibleDays = showWeekends ? week : week.filter { !$0.isWeekend }
                                let containsToday = visibleDays.contains(where: \.isToday)

                                if let banner = calendarViewModel.monthBannerForWeek(week) {
                                    let monthDate = week.first(where: { Calendar.current.component(.day, from: $0.date) == 1 })?.date ?? week.first!.date
                                    MonthBanner(
                                        title: banner,
                                        totalMinutes: calendarViewModel.totalMinutesForMonth(containing: monthDate)
                                    )
                                }

                                HStack(spacing: 0) {
                                    ForEach(visibleDays) { day in
                                        CalendarCell(
                                            day: day,
                                            isSelected: selectedDay?.dateString == day.dateString,
                                            onSelect: {
                                                withAnimation(.easeOut(duration: 0.15)) {
                                                    if selectedDay?.dateString == day.dateString {
                                                        selectedDay = nil
                                                    } else {
                                                        selectedDay = day
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }
                                .id(containsToday ? "today-week" : "week-\(weekIndex)")
                            }
                        }
                    }
                    .onAppear {
                        scrollProxy = proxy
                        DispatchQueue.main.async {
                            proxy.scrollTo("today-week", anchor: .center)
                        }
                    }
                }
            }

            // Inspector sidebar
            if let selectedDay {
                Divider()
                DayInspector(
                    day: selectedDay,
                    projects: appState.sidebarProjects,
                    onUpdate: { entry, date, minutes, projectId, description in
                        guard let client = appState.client else { return }
                        let _ = try? await client.updateEntry(
                            id: entry.id, date: date, minutes: minutes,
                            projectId: projectId, description: description
                        )
                        await calendarViewModel.loadInitialRange()
                        refreshSelectedDay()
                    },
                    onDelete: { entry in
                        guard let client = appState.client else { return }
                        try? await client.deleteEntry(id: entry.id)
                        await calendarViewModel.loadInitialRange()
                        refreshSelectedDay()
                    },
                    onCreate: { date, minutes, projectId, description in
                        guard let client = appState.client else { return }
                        let _ = try? await client.createEntry(
                            date: date, minutes: minutes,
                            projectId: projectId, description: description
                        )
                        await calendarViewModel.loadInitialRange()
                        refreshSelectedDay()
                    },
                    defaultProjectId: appState.defaultProjectId,
                    onAdvanceToNextEmptyDay: { advanceToNextEmptyDay() },
                    onClose: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            self.selectedDay = nil
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Days", selection: $showWeekends) {
                    Text("Weekdays").tag(false)
                    Text("All days").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { scrollToToday() }) {
                    Label("Today", systemImage: "\(Calendar.current.component(.day, from: Date())).calendar")
                        .imageScale(.large)
                }
            }
        }
        .task { await calendarViewModel.loadInitialRange() }
    }

    private func scrollToToday() {
        withAnimation(.easeOut(duration: 0.3)) {
            scrollProxy?.scrollTo("today-week", anchor: .center)
        }
    }

    private func advanceToNextEmptyDay() {
        guard let current = selectedDay else { return }
        let calendar = Calendar.current
        var candidate = calendar.date(byAdding: .day, value: 1, to: current.date)!

        // Walk forward to find the next day with no entries
        for _ in 0..<365 {
            let dateString = TimeFormatter.apiDateString(candidate)
            let entries = calendarViewModel.entriesByDate[dateString] ?? []
            if entries.isEmpty {
                let isWeekend = calendar.isDateInWeekend(candidate)
                // Skip weekends if weekends are hidden
                if !showWeekends && isWeekend {
                    candidate = calendar.date(byAdding: .day, value: 1, to: candidate)!
                    continue
                }
                withAnimation(.easeOut(duration: 0.15)) {
                    selectedDay = CalendarDay(
                        date: candidate,
                        dateString: dateString,
                        entries: [],
                        totalMinutes: 0,
                        isToday: calendar.isDateInToday(candidate),
                        isWeekend: isWeekend
                    )
                }
                return
            }
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate)!
        }
    }

    private func refreshSelectedDay() {
        guard let selected = selectedDay else { return }
        let dateString = selected.dateString
        let entries = calendarViewModel.entriesByDate[dateString] ?? []
        let totalMinutes = entries.reduce(0) { $0 + $1.minutes }
        selectedDay = CalendarDay(
            date: selected.date,
            dateString: dateString,
            entries: entries,
            totalMinutes: totalMinutes,
            isToday: selected.isToday,
            isWeekend: selected.isWeekend
        )
    }
}
