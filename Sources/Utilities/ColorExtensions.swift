import SwiftUI

extension Color {
    /// Create a Color from a hex string like "#ff9898" or "ff9898"
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

extension NokoProject {
    var swiftUIColor: Color {
        Color(hex: color ?? "#3b82f6")
    }
}

extension ProjectRef {
    var swiftUIColor: Color {
        Color(hex: color ?? "#3b82f6")
    }
}
