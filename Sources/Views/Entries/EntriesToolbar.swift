import SwiftUI

struct EntriesToolbar: View {
    @Binding var searchQuery: String
    @Binding var selectedProjectId: Int?
    let projects: [NokoProject]
    let onSearch: () -> Void
    let onServerSearch: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                TextField("Search entries…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        onSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.fill.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Project filter
            Picker("Project", selection: $selectedProjectId) {
                Text("All Projects").tag(nil as Int?)
                ForEach(projects) { project in
                    Text(project.name).tag(project.id as Int?)
                }
            }
            .labelsHidden()
            .frame(width: 150)
            .onChange(of: selectedProjectId) { onSearch() }

            // Server search fallback
            if !searchQuery.isEmpty {
                Button("Search all") {
                    onServerSearch()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
