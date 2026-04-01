import SwiftUI

struct DayInspector: View {
    let day: CalendarDay
    let projects: [NokoProject]
    let onUpdate: (NokoEntry, String?, Int?, Int?, String?) async -> Void
    let onDelete: (NokoEntry) async -> Void
    let onCreate: (Date, Int, Int?, String?) async -> Void
    let defaultProjectId: Int?
    let onAdvanceToNextEmptyDay: () -> Void
    let onClose: () -> Void

    @AppStorage("lastEntryDescription") private var lastDescription = ""
    @AppStorage("lastEntryDuration") private var lastDuration = ""
    @AppStorage("inspectorGoToNextDay") private var goToNextDay = false

    @State private var newDescription = ""
    @State private var newDuration = ""
    @State private var newProjectId: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimeFormatter.relativeDayLabel(day.date))
                        .font(.headline)
                    Text(TimeFormatter.displayDate(day.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let total = day.formattedTotal {
                    Text(total)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            // Entries list
            ScrollView {
                VStack(spacing: 8) {
                    if day.entries.isEmpty {
                        Text("No entries")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(day.entries) { entry in
                            DayInspectorEntryRow(
                                entry: entry,
                                projects: projects,
                                onUpdate: onUpdate,
                                onDelete: onDelete
                            )
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            // New entry form
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Entry")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("0:00", text: $newDuration)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                        .frame(width: 80)

                    TextField("Description", text: $newDescription)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                }

                HStack(spacing: 8) {
                    Picker("Project", selection: $newProjectId) {
                        Text("No project")
                            .frame(maxWidth: .infinity)
                            .tag(nil as Int?)
                        ForEach(projects) { project in
                            Text(project.name).tag(project.id as Int?)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)

                    Toggle("Go to next day", isOn: $goToNextDay)
                        .controlSize(.small)
                }

                Button {
                    guard let minutes = TimeFormatter.parseToMinutes(newDuration), minutes > 0 else { return }
                    Task {
                        lastDescription = newDescription
                        lastDuration = newDuration
                        await onCreate(day.date, minutes, newProjectId, newDescription.isEmpty ? nil : newDescription)
                        if goToNextDay {
                            onAdvanceToNextEmptyDay()
                        }
                    }
                } label: {
                    Text("Add")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(newDuration.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 300)
        .background(.bar)
        .onAppear {
            newProjectId = defaultProjectId
            newDescription = lastDescription
            newDuration = lastDuration
        }
    }
}

struct DayInspectorEntryRow: View {
    let entry: NokoEntry
    let projects: [NokoProject]
    let onUpdate: (NokoEntry, String?, Int?, Int?, String?) async -> Void
    let onDelete: (NokoEntry) async -> Void

    @State private var isEditing = false
    @State private var editDescription: String = ""
    @State private var editDuration: String = ""
    @State private var editProjectId: Int?
    @State private var editDate: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                editingView
            } else {
                displayView
            }
        }
        .padding(10)
        .background(.fill.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var displayView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(entry.project?.swiftUIColor ?? .gray)
                    .frame(width: 6, height: 6)
                Text(entry.description ?? "Untitled")
                    .font(.callout)
                    .lineLimit(2)
                Spacer()
                Text(entry.formattedDuration)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(entry.project?.name ?? "No project")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(action: { startEditing() }) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button(action: { Task { await onDelete(entry) } }) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var editingView: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Description", text: $editDescription)
                .textFieldStyle(.roundedBorder)
                .font(.callout)

            HStack(spacing: 8) {
                TextField("Duration", text: $editDuration)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .frame(width: 70)

                Picker("Project", selection: $editProjectId) {
                    Text("No project").tag(nil as Int?)
                    ForEach(projects) { project in
                        Text(project.name).tag(project.id as Int?)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
            }

            HStack {
                Button("Cancel") { isEditing = false }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Spacer()
                Button("Save") { saveEdit() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }

    private func startEditing() {
        editDescription = entry.description ?? ""
        editDuration = entry.formattedDuration
        editProjectId = entry.project?.id
        editDate = entry.date
        isEditing = true
    }

    private func saveEdit() {
        let minutes = TimeFormatter.parseToMinutes(editDuration)
        Task {
            await onUpdate(
                entry,
                editDate != entry.date ? editDate : nil,
                minutes != entry.minutes ? minutes : nil,
                editProjectId != entry.project?.id ? editProjectId : nil,
                editDescription != (entry.description ?? "") ? editDescription : nil
            )
            isEditing = false
        }
    }
}
