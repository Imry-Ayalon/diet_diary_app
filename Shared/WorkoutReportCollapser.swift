import Foundation
import SwiftData

/// Represents an item in daily or weekly reports.
struct ReportItem: Identifiable, Sendable {
    let id: String
    let title: String
    let notes: String
    let imageData: Data?
    let date: Date
    let count: Int

    init(entry: FoodEntry) {
        self.id = "\(entry.persistentModelID)"
        self.title = entry.title
        self.notes = entry.notes
        self.imageData = entry.imageData
        self.date = entry.date
        self.count = 1
    }

    init(id: String, title: String, notes: String, imageData: Data?, date: Date, count: Int = 1) {
        self.id = id
        self.title = title
        self.notes = notes
        self.imageData = imageData
        self.date = date
        self.count = count
    }
}

/// Parses and aggregates workout metrics (kilometers, duration, ascent, calories).
struct WorkoutMetrics: Sendable {
    var distanceKm: Double = 0
    var minutes: Int = 0
    var ascentMeters: Double = 0
    var calories: Int = 0
    var hasDistance: Bool = false
    var hasMinutes: Bool = false
    var hasAscent: Bool = false
    var hasCalories: Bool = false
    var extraNotes: [String] = []

    static func parse(_ text: String) -> WorkoutMetrics {
        var metrics = WorkoutMetrics()
        let separators = CharacterSet(charactersIn: "·\n;")
        let segments = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for segment in segments {
            var matched = false

            // Distance: e.g. 12.3 ק״מ, 12,3 ק"מ, 5 קמ, 10 km
            let distPattern = #"(?i)^(\d+(?:[.,]\d+)?)\s*(?:ק״מ|ק"מ|ק׳׳מ|ק''מ|קמ|km)$"#
            if let regex = try? NSRegularExpression(pattern: distPattern),
               let match = regex.firstMatch(in: segment, range: NSRange(segment.startIndex..., in: segment)),
               let range = Range(match.range(at: 1), in: segment) {
                let numStr = String(segment[range]).replacingOccurrences(of: ",", with: ".")
                if let val = Double(numStr) {
                    metrics.distanceKm += val
                    metrics.hasDistance = true
                    matched = true
                }
            }

            // Minutes: e.g. 35 דק׳, 40 דק', 25 דקות, 30 min
            let minPattern = #"(?i)^(\d+)\s*(?:דק׳|דק'|דקות|דק|min)$"#
            if !matched,
               let regex = try? NSRegularExpression(pattern: minPattern),
               let match = regex.firstMatch(in: segment, range: NSRange(segment.startIndex..., in: segment)),
               let range = Range(match.range(at: 1), in: segment) {
                if let val = Int(segment[range]) {
                    metrics.minutes += val
                    metrics.hasMinutes = true
                    matched = true
                }
            }

            // Ascent: e.g. 80 מ׳ עלייה, 95 מ' עלייה, 100 מ עלייה, 50 עלייה
            let ascentPattern = #"(?i)^(\d+(?:[.,]\d+)?)\s*(?:מ׳|מ'|מ|m)?\s*(?:עלייה|עליה|ascent)$"#
            if !matched,
               let regex = try? NSRegularExpression(pattern: ascentPattern),
               let match = regex.firstMatch(in: segment, range: NSRange(segment.startIndex..., in: segment)),
               let range = Range(match.range(at: 1), in: segment) {
                let numStr = String(segment[range]).replacingOccurrences(of: ",", with: ".")
                if let val = Double(numStr) {
                    metrics.ascentMeters += val
                    metrics.hasAscent = true
                    matched = true
                }
            }

            // Calories: e.g. כ-280 קק״ל, כ - 280 קק"ל, 320 קקל, 150 קלוריות, 200 kcal
            let calPattern = #"(?i)^(?:כ\s*[-–—]?\s*|~)?\s*(\d+)\s*(?:קק״ל|קק"ל|קק׳׳ל|קק''ל|קקל|קלוריות|kcal|cal)$"#
            if !matched,
               let regex = try? NSRegularExpression(pattern: calPattern),
               let match = regex.firstMatch(in: segment, range: NSRange(segment.startIndex..., in: segment)),
               let range = Range(match.range(at: 1), in: segment) {
                if let val = Int(segment[range]) {
                    metrics.calories += val
                    metrics.hasCalories = true
                    matched = true
                }
            }

            if !matched {
                metrics.extraNotes.append(segment)
            }
        }

        return metrics
    }

    mutating func combine(with other: WorkoutMetrics) {
        if other.hasDistance {
            self.distanceKm += other.distanceKm
            self.hasDistance = true
        }
        if other.hasMinutes {
            self.minutes += other.minutes
            self.hasMinutes = true
        }
        if other.hasAscent {
            self.ascentMeters += other.ascentMeters
            self.hasAscent = true
        }
        if other.hasCalories {
            self.calories += other.calories
            self.hasCalories = true
        }
        for note in other.extraNotes {
            if !self.extraNotes.contains(note) {
                self.extraNotes.append(note)
            }
        }
    }

    func formattedNotes() -> String {
        var parts: [String] = []
        if hasDistance {
            parts.append(String(format: "%.1f ק״מ", distanceKm))
        }
        if hasMinutes && minutes > 0 {
            parts.append("\(minutes) דק׳")
        }
        if hasAscent && ascentMeters > 0 {
            parts.append("\(Int(ascentMeters.rounded())) מ׳ עלייה")
        }
        if hasCalories && calories > 0 {
            parts.append("כ-\(calories) קק״ל")
        }
        parts.append(contentsOf: extraNotes)
        return parts.joined(separator: " · ")
    }
}

enum WorkoutCategory: Equatable {
    case ride
    case run
    case other
}

enum WorkoutReportCollapser {
    static func category(for entry: FoodEntry) -> WorkoutCategory {
        guard entry.mealType == .workout else { return .other }
        let lower = entry.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.contains("רכיב") || lower.contains("אופנ") || lower.contains("ride") || lower.contains("cycl") || lower.contains("bike") {
            return .ride
        }
        if lower.contains("ריצ") || lower.contains("רצים") || lower.contains("run") || lower.contains("jog") {
            return .run
        }
        return .other
    }

    static func collapse(entries: [FoodEntry]) -> [ReportItem] {
        guard !entries.isEmpty else { return [] }

        guard entries.first?.mealType == .workout else {
            return entries.map { ReportItem(entry: $0) }
        }

        var rides: [FoodEntry] = []
        var runs: [FoodEntry] = []
        var others: [FoodEntry] = []

        for entry in entries {
            switch category(for: entry) {
            case .ride:
                rides.append(entry)
            case .run:
                runs.append(entry)
            case .other:
                others.append(entry)
            }
        }

        var result: [ReportItem] = []

        // Collapse rides
        if rides.count == 1 {
            result.append(ReportItem(entry: rides[0]))
        } else if rides.count > 1 {
            result.append(collapseGroup(entries: rides, defaultTitle: "רכיבת אופניים", idPrefix: "collapsed-ride"))
        }

        // Collapse runs
        if runs.count == 1 {
            result.append(ReportItem(entry: runs[0]))
        } else if runs.count > 1 {
            result.append(collapseGroup(entries: runs, defaultTitle: "ריצה", idPrefix: "collapsed-run"))
        }

        // Keep other workouts untouched
        for other in others {
            result.append(ReportItem(entry: other))
        }

        return result.sorted { $0.date < $1.date }
    }

    private static func collapseGroup(entries: [FoodEntry], defaultTitle: String, idPrefix: String) -> ReportItem {
        let sorted = entries.sorted { $0.date < $1.date }
        let earliestDate = sorted.first?.date ?? Date()
        let firstID = sorted.first.map { "\($0.persistentModelID)" } ?? UUID().uuidString
        let image = sorted.compactMap(\.imageData).first

        var combinedMetrics = WorkoutMetrics()
        for entry in sorted {
            let metrics = WorkoutMetrics.parse(entry.notes)
            combinedMetrics.combine(with: metrics)
        }

        let combinedNotes = combinedMetrics.formattedNotes()

        return ReportItem(
            id: "\(idPrefix)-\(firstID)",
            title: defaultTitle,
            notes: combinedNotes,
            imageData: image,
            date: earliestDate,
            count: entries.count
        )
    }
}
