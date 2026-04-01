import SwiftUI

struct ProjectBreakdown: View {
    let projects: [ProjectData]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By Project")
                .font(.headline)

            ForEach(projects) { project in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(project.color)
                        .frame(width: 8, height: 8)

                    Text(project.name)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.fill.quinary)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(project.color)
                                .frame(width: geo.size.width * project.percentage)
                        }
                    }
                    .frame(width: 160, height: 5)

                    Text(TimeFormatter.minutesToDisplay(project.minutes))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)

                    Text(String(format: "%.0f%%", project.percentage * 100))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
    }
}
