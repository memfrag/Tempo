import SwiftUI

struct TodayEntriesList: View {
    let entries: [NokoEntry]
    let totalMinutes: Int
    let onResume: (NokoEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today")
                    .font(.headline)
                Spacer()
                Text("Total: \(TimeFormatter.minutesToDisplay(totalMinutes))")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            if entries.isEmpty {
                Text("No entries yet today")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 2) {
                    ForEach(entries) { entry in
                        EntryRowCompact(entry: entry, onResume: { onResume(entry) })
                    }
                }
            }
        }
    }
}

struct EntryRowCompact: View {
    let entry: NokoEntry
    let onResume: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(entry.project?.swiftUIColor ?? .gray)
                .frame(width: 3, height: 28)

            // Info
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.description ?? "Untitled")
                    .font(.callout)
                    .lineLimit(1)
                Text(entry.project?.name ?? "No Project")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Duration
            Text(entry.formattedDuration)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)

            // Hover actions
            if isHovered {
                Button(action: onResume) {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? AnyShapeStyle(.fill.quinary) : AnyShapeStyle(.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
