import SwiftUI

struct BarChart: View {
    let days: [DayData]
    let maxMinutes: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    // Hours label
                    Text(String(format: "%.1fh", day.hours))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    // Stacked bar
                    VStack(spacing: 1) {
                        ForEach(Array(day.projectSegments.enumerated()), id: \.offset) { _, seg in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(seg.project?.swiftUIColor ?? .gray)
                                .frame(height: barHeight(minutes: seg.minutes))
                        }
                    }
                    .frame(maxWidth: 48)
                    .frame(height: totalBarHeight(day: day), alignment: .bottom)

                    // Day label
                    Text(day.label)
                        .font(.caption)
                        .foregroundStyle(day.isToday ? .blue : .secondary)
                        .fontWeight(day.isToday ? .semibold : .regular)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 180)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func barHeight(minutes: Int) -> CGFloat {
        guard maxMinutes > 0 else { return 0 }
        return max(2, CGFloat(minutes) / CGFloat(maxMinutes) * 140)
    }

    private func totalBarHeight(day: DayData) -> CGFloat {
        guard maxMinutes > 0 else { return 0 }
        return max(0, CGFloat(day.minutes) / CGFloat(maxMinutes) * 140)
    }
}
