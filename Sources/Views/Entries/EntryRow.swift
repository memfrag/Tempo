import SwiftUI

struct EntryRow: View {
    let entry: NokoEntry
    let onResume: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editDescription: String = ""
    @State private var editDuration: String = ""

    var body: some View {
        HStack(spacing: 12) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(entry.project?.swiftUIColor ?? .gray)
                .frame(width: 3, height: 32)

            // Entry info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.description ?? "Untitled")
                    .font(.callout)
                    .lineLimit(1)
                if let project = entry.project {
                    ProjectTag(name: project.name, color: project.swiftUIColor)
                }
            }

            Spacer()

            // Time range (approximate)
            Text(entry.date)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.quaternary)

            // Duration
            Text(entry.formattedDuration)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .trailing)

            // Hover actions
            if isHovered {
                HStack(spacing: 2) {
                    Button(action: onResume) {
                        Image(systemName: "play.fill")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Resume")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Delete")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovered ? AnyShapeStyle(.fill.quinary) : AnyShapeStyle(.clear))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
