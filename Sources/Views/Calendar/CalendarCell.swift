import SwiftUI

struct CalendarCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Date header
            HStack {
                Text("\(day.dayNumber)")
                    .font(.body)
                    .fontWeight((day.isToday || isSelected) ? .bold : .medium)
                    .foregroundStyle(highlightColor ?? (day.entries.isEmpty ? .secondary : .primary))
                Spacer()
                if let total = day.formattedTotal {
                    Text(total)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(highlightColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.tertiary))
                }
            }
            .padding(.bottom, 2)

            // Entry pills (max 3)
            let visible = Array(day.entries.prefix(3))
            ForEach(visible) { entry in
                HStack(spacing: 3) {
                    Circle()
                        .fill(entry.project?.swiftUIColor ?? .gray)
                        .frame(width: 4, height: 4)
                    Text(entry.project?.name ?? "—")
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(entry.formattedDuration)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    (entry.project?.swiftUIColor ?? .gray).opacity(0.1)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                )
            }

            // Overflow
            if day.entries.count > 3 {
                Text("+\(day.entries.count - 3) more")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(5)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .background {
            if isSelected {
                Color.green.opacity(0.08)
            } else if day.isToday {
                Color.blue.opacity(0.05)
            } else if day.isWeekend {
                Color.primary.opacity(0.02)
            }
        }
        .overlay(alignment: .top) {
            if isSelected {
                Rectangle()
                    .fill(.green)
                    .frame(height: 2)
            } else if day.isToday {
                Rectangle()
                    .fill(.blue)
                    .frame(height: 2)
            }
        }
        .overlay {
            Rectangle()
                .stroke(.separator, lineWidth: 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }

    private var highlightColor: Color? {
        if isSelected { return .green }
        if day.isToday { return .blue }
        return nil
    }
}
