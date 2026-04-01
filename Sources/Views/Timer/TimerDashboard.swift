import SwiftUI

struct TodayDashboard: View {
    @Environment(AppState.self) private var appState
    @Bindable var todayViewModel: TodayViewModel

    @State private var showNewEntry = false
    @State private var newDescription = ""
    @State private var newDuration = ""
    @State private var newProjectId: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statsStrip

                newEntryBar

                TodayEntriesList(
                    entries: todayViewModel.todayEntries,
                    totalMinutes: todayViewModel.todayTotal,
                    onResume: { _ in }
                )
            }
            .padding(24)
        }
        .task { await todayViewModel.loadAll() }
        .onAppear { newProjectId = appState.defaultProjectId }
    }

    private var statsStrip: some View {
        HStack(spacing: 12) {
            StatBox(label: "Today", value: TimeFormatter.minutesToDisplay(todayViewModel.todayTotal), accent: true)
            StatBox(label: "This Week", value: String(format: "%.1fh", todayViewModel.weekTotal))
            StatBox(label: "This Month", value: String(format: "%.1fh", todayViewModel.monthTotal))
            StatBox(label: "Entries", value: "\(todayViewModel.entryCount)")
        }
    }

    private var newEntryBar: some View {
        HStack(spacing: 8) {
            TextField("What did you work on?", text: $newDescription)
                .textFieldStyle(.roundedBorder)
                .onSubmit { createEntry() }

            TextField("Duration (e.g. 1:30)", text: $newDuration)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)

            Picker("Project", selection: $newProjectId) {
                if let defaultProject = appState.defaultProject {
                    Text("Default (\(defaultProject.name))").tag(nil as Int?)
                }
                ForEach(appState.projects) { project in
                    Text(project.name).tag(project.id as Int?)
                }
            }
            .labelsHidden()
            .frame(width: 160)

            Button(action: createEntry) {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(newDescription.isEmpty || newDuration.isEmpty)
        }
    }

    private func createEntry() {
        guard !newDescription.isEmpty,
              let minutes = TimeFormatter.parseToMinutes(newDuration),
              minutes > 0 else { return }
        let projectId = newProjectId ?? appState.defaultProject?.id
        Task {
            await todayViewModel.createEntry(
                date: Date(),
                minutes: minutes,
                projectId: projectId,
                description: newDescription
            )
            newDescription = ""
            newDuration = ""
        }
    }
}

struct StatBox: View {
    let label: String
    let value: String
    var accent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(.title2, design: .monospaced, weight: .regular))
                .foregroundStyle(accent ? .blue : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.fill.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
