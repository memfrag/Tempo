import SwiftUI

struct ProjectsView: View {
    @Bindable var projectsViewModel: ProjectsViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Projects")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Link(destination: URL(string: "https://secure.nokotime.com/projects")!) {
                        Label("Manage in Noko", systemImage: "arrow.up.right.square")
                            .font(.callout)
                    }
                }

                if projectsViewModel.isLoading && projectsViewModel.projectStats.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading project stats…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    // Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ], spacing: 12) {
                        ForEach(projectsViewModel.projectStats) { stat in
                            ProjectCard(stat: stat)
                        }
                    }
                }
            }
            .padding(24)
        }
        .task { await projectsViewModel.loadStats() }
    }
}
