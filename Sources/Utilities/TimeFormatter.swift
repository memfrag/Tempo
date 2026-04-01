import Foundation

enum TimeFormatter {

    /// Parse flexible time input to minutes.
    /// Accepts: "1.5" (decimal hours), "1:30" (h:mm), "90" (treated as minutes if > 24)
    static func parseToMinutes(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // h:mm format
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":")
            guard parts.count == 2,
                  let hours = Int(parts[0]),
                  let mins = Int(parts[1]),
                  hours >= 0, mins >= 0, mins < 60 else { return nil }
            return hours * 60 + mins
        }

        // Decimal hours (e.g. "1.5" → 90 minutes)
        if let value = Double(trimmed) {
            if value < 0 { return nil }
            return Int((value * 60).rounded())
        }

        return nil
    }

    /// Convert minutes to display string "H:MM" or "Nh" if even hours
    static func minutesToDisplay(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return "\(h)h" }
        return "\(h):\(String(format: "%02d", m))"
    }

    /// Convert seconds to display string "H:MM:SS"
    static func secondsToDisplay(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", s))"
    }

    /// Convert seconds to short display "H:MM"
    static func secondsToShortDisplay(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h):\(String(format: "%02d", m))"
    }

    /// Convert minutes to decimal hours string (e.g. 90 → "1.5")
    static func minutesToDecimalHours(_ minutes: Int) -> String {
        let hours = Double(minutes) / 60.0
        if hours == hours.rounded() {
            return String(format: "%.0f", hours)
        }
        return String(format: "%.1f", hours)
    }

    /// Format a date as "YYYY-MM-DD" for Noko API
    static func apiDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Parse "YYYY-MM-DD" string to Date
    static func parseAPIDate(_ string: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: string)
    }

    /// Human-readable date: "Mon, Mar 31"
    static func displayDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    /// Relative day label: "Today", "Yesterday", or "Mon, Mar 31"
    static func relativeDayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return displayDate(date)
    }
}
