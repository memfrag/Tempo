import SwiftUI

struct MenuBarPopover: View {
    @Environment(AppState.self) private var appState
    @State private var todayEntries: [NokoEntry] = []
    @State private var todayTotal: Int = 0

    @State private var newDescription = ""
    @State private var newDuration = ""
    @State private var newProjectId: Int?
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tempo")
                    .font(.callout)
                    .fontWeight(.semibold)
                Spacer()
                Text("Today: \(TimeFormatter.minutesToDisplay(todayTotal))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)

            Divider()

            quickEntryForm

            Divider()

            if todayEntries.isEmpty {
                Text("No entries today")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    ForEach(todayEntries.prefix(5)) { entry in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(entry.project?.swiftUIColor ?? .gray)
                                .frame(width: 5, height: 5)
                            Text(entry.description ?? "Untitled")
                                .font(.callout)
                                .lineLimit(1)
                            Spacer()
                            Text(entry.formattedDuration)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                }
            }

            Divider()
                .padding(.top, 4)

            HStack {
                Button("Open Tempo") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.title == "Tempo" || $0.isKeyWindow }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()
            }
            .padding(12)
        }
        .frame(width: 300)
        .task { await loadToday() }
        .onAppear { newProjectId = appState.defaultProjectId }
    }

    private var quickEntryForm: some View {
        VStack(spacing: 8) {
            TextField("What did you work on?", text: $newDescription)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
                .onSubmit { submitEntry() }

            HStack(spacing: 8) {
                TextField("e.g. 1:30", text: $newDuration)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .frame(width: 70)

                Picker("Project", selection: $newProjectId) {
                    if let defaultProject = appState.defaultProject {
                        Text(defaultProject.name).tag(nil as Int?)
                    }
                    ForEach(appState.projects) { project in
                        Text(project.name).tag(project.id as Int?)
                    }
                }
                .labelsHidden()
                .font(.callout)

                Button(action: submitEntry) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .disabled(newDescription.isEmpty || newDuration.isEmpty || isSubmitting)
            }
        }
        .padding(12)
    }

    private func submitEntry() {
        guard !newDescription.isEmpty,
              let client = appState.client,
              let minutes = TimeFormatter.parseToMinutes(newDuration),
              minutes > 0 else { return }
        let projectId = newProjectId ?? appState.defaultProject?.id
        let description = newDescription
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                let entry = try await client.createEntry(
                    date: Date(),
                    minutes: minutes,
                    projectId: projectId,
                    description: description
                )
                todayEntries.insert(entry, at: 0)
                todayTotal += entry.minutes
                newDescription = ""
                newDuration = ""
            } catch {}
        }
    }

    private func loadToday() async {
        guard let client = appState.client else { return }
        do {
            let today = Date()
            let result = try await client.entries(from: today, to: today, userId: appState.currentUserId)
            self.todayEntries = result.entries
            self.todayTotal = result.entries.reduce(0) { $0 + $1.minutes }
        } catch {}
    }
}
