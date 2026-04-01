import SwiftUI

struct MonthBanner: View {
    let title: String
    let totalMinutes: Int

    private var monthName: String {
        title.components(separatedBy: " ").first ?? title
    }

    private var year: String {
        title.components(separatedBy: " ").last ?? ""
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(monthName)
                .font(.title)
                .fontWeight(.bold)
            Text(year)
                .font(.title)
                .fontWeight(.thin)
                .foregroundStyle(.tertiary)
            Spacer()
            if totalMinutes > 0 {
                Text(TimeFormatter.minutesToDisplay(totalMinutes))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
