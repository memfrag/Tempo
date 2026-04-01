import SwiftUI

@MainActor @Observable
final class EntriesViewModel {
    var entries: [NokoEntry] = []
    var isLoading = false
    var error: String?
    var searchQuery = ""
    var selectedProjectId: Int?
    var currentPage = 1
    var hasMore = false
    var totalLoaded = 0

    // Undo support
    var recentlyDeleted: NokoEntry?
    var showUndoToast = false
    private var undoTask: Task<Void, Never>?

    private var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var client: NokoClient? { appState.client }

    /// Entries grouped by date
    var groupedEntries: [(date: Date, entries: [NokoEntry])] {
        let filtered: [NokoEntry]
        if searchQuery.isEmpty {
            filtered = entries
        } else {
            let q = searchQuery.lowercased()
            filtered = entries.filter {
                ($0.description?.lowercased().contains(q) ?? false) ||
                ($0.project?.name.lowercased().contains(q) ?? false)
            }
        }

        let grouped = Dictionary(grouping: filtered) { $0.date }
        return grouped.sorted { $0.key > $1.key }
            .compactMap { dateStr, entries in
                guard let date = TimeFormatter.parseAPIDate(dateStr) else { return nil }
                return (date: date, entries: entries)
            }
    }

    // MARK: - Loading

    func loadEntries() async {
        guard let client else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            currentPage = 1
            let result = try await client.entries(
                projectIds: selectedProjectId.map { [$0] },
                userId: appState.currentUserId,
                page: 1
            )
            entries = result.entries
            hasMore = result.hasMore
            totalLoaded = entries.count
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadMore() async {
        guard let client, hasMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            currentPage += 1
            let result = try await client.entries(
                projectIds: selectedProjectId.map { [$0] },
                userId: appState.currentUserId,
                page: currentPage
            )
            entries.append(contentsOf: result.entries)
            hasMore = result.hasMore
            totalLoaded = entries.count
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Server-side search (fallback when local filter isn't enough)
    func searchServer() async {
        guard let client, !searchQuery.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            // Noko doesn't have a direct description search param on entries,
            // so we load more pages and filter. In practice, we fetch up to 500.
            var all: [NokoEntry] = []
            for page in 1...5 {
                let result = try await client.entries(userId: appState.currentUserId, page: page, perPage: 100)
                all.append(contentsOf: result.entries)
                if !result.hasMore { break }
            }
            let q = searchQuery.lowercased()
            entries = all.filter {
                ($0.description?.lowercased().contains(q) ?? false) ||
                ($0.project?.name.lowercased().contains(q) ?? false)
            }
            hasMore = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Create/Edit/Delete

    func createEntry(date: Date, minutes: Int, projectId: Int?, description: String?) async {
        guard let client else { return }
        do {
            let entry = try await client.createEntry(
                date: date, minutes: minutes,
                projectId: projectId, description: description
            )
            entries.insert(entry, at: 0)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateEntry(_ entry: NokoEntry, date: String?, minutes: Int?, projectId: Int?, description: String?) async {
        guard let client else { return }
        do {
            let updated = try await client.updateEntry(
                id: entry.id, date: date, minutes: minutes,
                projectId: projectId, description: description
            )
            if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[idx] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: NokoEntry) async {
        guard let client else { return }
        do {
            try await client.deleteEntry(id: entry.id)
            entries.removeAll { $0.id == entry.id }

            // Undo support
            await MainActor.run {
                recentlyDeleted = entry
                showUndoToast = true
                undoTask?.cancel()
                undoTask = Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.recentlyDeleted = nil
                            self.showUndoToast = false
                        }
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func undoDelete() async {
        guard let client, let entry = recentlyDeleted else { return }
        undoTask?.cancel()
        showUndoToast = false

        do {
            let restored = try await client.createEntry(
                date: entry.parsedDate ?? Date(),
                minutes: entry.minutes,
                projectId: entry.project?.id,
                description: entry.description
            )
            entries.insert(restored, at: 0)
            recentlyDeleted = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
