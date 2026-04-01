import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case today = "Today"
    case entries = "Entries"
    case reports = "Reports"
    case calendar = "Calendar"
    case projects = "Projects"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: return "clock.fill"
        case .entries: return "list.bullet"
        case .reports: return "chart.bar.fill"
        case .calendar: return "calendar"
        case .projects: return "folder.fill"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem
    @Environment(AppState.self) private var appState
    @State private var showProjectPicker = false

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
            }

            Section {
                ForEach(appState.sidebarProjects) { project in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(project.swiftUIColor)
                            .frame(width: 8, height: 8)
                        Text(project.name)
                            .font(.callout)
                            .lineLimit(1)
                    }
                    .badge(project.id == appState.defaultProjectId ? "★" : "")
                    .contextMenu {
                        if project.id == appState.defaultProjectId {
                            Button("Unset as Default") {
                                appState.defaultProjectId = nil
                            }
                        } else {
                            Button("Set as Default") {
                                appState.defaultProjectId = project.id
                            }
                        }
                        Divider()
                        Button("Remove from Sidebar") {
                            appState.removeSidebarProject(project)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Projects")
                    Spacer()
                    Button(action: { showProjectPicker = true }) {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .sheet(isPresented: $showProjectPicker) {
            SidebarProjectPicker()
                .environment(appState)
        }
    }
}

struct SidebarProjectPicker: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredProjects: [NokoProject] {
        if searchText.isEmpty {
            return appState.projects
        }
        let query = searchText.lowercased()
        return appState.projects.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Projects to Sidebar")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(16)

            TextField("Search projects…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            List {
                ForEach(filteredProjects) { project in
                    let isSelected = appState.sidebarProjectIds.contains(project.id)
                    Button(action: {
                        if isSelected {
                            appState.removeSidebarProject(project)
                        } else {
                            appState.addSidebarProject(project)
                        }
                    }) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(project.swiftUIColor)
                                .frame(width: 8, height: 8)
                            Text(project.name)
                                .font(.callout)
                                .foregroundStyle(.primary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 360, height: 420)
    }
}
