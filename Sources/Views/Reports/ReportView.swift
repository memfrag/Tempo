import SwiftUI

struct ReportView: View {
    @Bindable var reportViewModel: ReportViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with nav
                HStack {
                    Text("Weekly Report")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    HStack(spacing: 10) {
                        Button(action: reportViewModel.previousWeek) {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        Text(reportViewModel.weekLabel)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button(action: reportViewModel.nextWeek) {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Bar chart
                BarChart(days: reportViewModel.dailyBreakdown, maxMinutes: reportViewModel.dailyBreakdown.map(\.minutes).max() ?? 480)

                // Stats row
                HStack(spacing: 12) {
                    StatBox(label: "Total", value: String(format: "%.1fh", reportViewModel.totalHours), accent: true)
                    StatBox(label: "Daily Avg", value: String(format: "%.1fh", reportViewModel.dailyAverage))
                    StatBox(label: "Top Project", value: reportViewModel.projectBreakdown.first?.name ?? "—")
                    StatBox(label: "Entries", value: "\(reportViewModel.weekEntries.count)")
                }

                // Project breakdown
                ProjectBreakdown(projects: reportViewModel.projectBreakdown)
            }
            .padding(24)
        }
        .task { await reportViewModel.loadWeek() }
    }
}
