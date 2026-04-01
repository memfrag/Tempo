import SwiftUI

struct ProjectCard: View {
    let stat: ProjectStat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(stat.project.swiftUIColor)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(String(stat.project.name.prefix(1)).uppercased())
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                Spacer()
            }

            // Name
            Text(stat.project.name)
                .font(.headline)
                .lineLimit(1)

            // Stats
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("WEEK")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Text(stat.weekHours)
                        .font(.system(.callout, design: .monospaced))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("MONTH")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Text(stat.monthHours)
                        .font(.system(.callout, design: .monospaced))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(stat.project.swiftUIColor)
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
