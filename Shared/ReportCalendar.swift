import Foundation

enum ReportCalendar {
    static let pageLimit = 12

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "he_IL")
        calendar.firstWeekday = 1
        return calendar
    }

    static func weeks(from start: Date, to end: Date) -> [[Date]] {
        let calendar = calendar
        let first = calendar.startOfDay(for: min(start, end))
        let last = calendar.startOfDay(for: max(start, end))
        let startWeekday = calendar.component(.weekday, from: first)
        let sunday = calendar.date(byAdding: .day, value: 1 - startWeekday, to: first) ?? first

        var weeks: [[Date]] = []
        var cursor = sunday
        while cursor <= last {
            let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: cursor) }
            weeks.append(days)
            guard let next = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = next
        }
        return weeks
    }

    static func thisWeek() -> (start: Date, end: Date) {
        week(containing: Date())
    }

    static func previousWeek() -> (start: Date, end: Date) {
        let calendar = calendar
        let current = thisWeek().start
        let previous = calendar.date(byAdding: .day, value: -7, to: current) ?? current
        return week(containing: previous)
    }

    static func thisMonth() -> (start: Date, end: Date) {
        month(containing: Date())
    }

    static func previousMonth() -> (start: Date, end: Date) {
        let calendar = calendar
        let thisStart = thisMonth().start
        let previous = calendar.date(byAdding: .month, value: -1, to: thisStart) ?? thisStart
        return month(containing: previous)
    }

    private static func week(containing date: Date) -> (start: Date, end: Date) {
        let days = weeks(from: date, to: date).first ?? [date]
        return (days.first ?? date, days.last ?? date)
    }

    private static func month(containing date: Date) -> (start: Date, end: Date) {
        let calendar = calendar
        let parts = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: parts) ?? date
        let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let end = calendar.date(byAdding: .day, value: dayCount - 1, to: start) ?? start
        return (start, end)
    }
}

enum ReportExportError: Error {
    case empty
}
