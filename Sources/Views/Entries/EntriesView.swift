import SwiftUI

struct EntriesView: View {
    @Bindable var entriesViewModel: EntriesViewModel
    @Environment(AppState.self) private var appState

    @State private var showCreateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            EntriesToolbar(
                searchQuery: $entriesViewModel.searchQuery,
                selectedProjectId: $entriesViewModel.selectedProjectId,
                projects: appState.sidebarProjects,
                onSearch: { Task { await entriesViewModel.loadEntries() } },
                onServerSearch: { Task { await entriesViewModel.searchServer() } }
            )

            // Entries list
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(entriesViewModel.groupedEntries, id: \.date) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                EntryRow(
                                    entry: entry,
                                    onResume: {
                                        guard (entry.project?.id) != nil else { return }
                                        // Resume will be handled by parent
                                    },
                                    onDelete: { Task { await entriesViewModel.deleteEntry(entry) } }
                                )
                            }
                        } header: {
                            dayHeader(date: group.date, entries: group.entries)
                        }
                    }

                    if entriesViewModel.hasMore {
                        Button("Load more") {
                            Task { await entriesViewModel.loadMore() }
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    }
                }
            }

            // Undo toast
            if entriesViewModel.showUndoToast {
                UndoToast(onUndo: { Task { await entriesViewModel.undoDelete() } })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Footer
            HStack {
                Text("Showing \(entriesViewModel.totalLoaded) entries")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .task {
            entriesViewModel.selectedProjectId = appState.defaultProjectId
            await entriesViewModel.loadEntries()
        }
    }

    private func dayHeader(date: Date, entries: [NokoEntry]) -> some View {
        HStack {
            Text(TimeFormatter.relativeDayLabel(date))
                .font(.callout)
                .fontWeight(.semibold)
            Text("— \(TimeFormatter.displayDate(date))")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            let total = entries.reduce(0) { $0 + $1.minutes }
            Text(TimeFormatter.minutesToDisplay(total))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
