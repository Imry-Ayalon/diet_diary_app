import Foundation

struct WeeklyReportPage {
    var dayNames: [String]
    var dates: [String]
    var rows: [Row]

    struct Row {
        var label: String
        var cells: [[Item]]
    }

    struct Item {
        var title: String
        var notes: String
        var imageJPEG: Data?
    }
}
