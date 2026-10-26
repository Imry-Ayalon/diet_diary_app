import SwiftUI

struct RideReportRangeSheet: View {
    @Binding var start: Date
    @Binding var end: Date
    let language: MovementLanguage
    let onShare: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var weekCount: Int {
        ReportCalendar.weeks(from: start, to: end).count
    }

    private var canShare: Bool {
        weekCount > 0 && weekCount <= ReportCalendar.pageLimit
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(MovementText.t("טווח תאריכים", "Date range", language)) {
                    DatePicker(MovementText.t("מתאריך", "From", language), selection: $start, displayedComponents: .date)
                    DatePicker(MovementText.t("עד תאריך", "To", language), selection: $end, displayedComponents: .date)
                }

                Section(MovementText.t("בחירה מהירה", "Quick pick", language)) {
                    Button(MovementText.t("השבוע", "This week", language)) { apply(ReportCalendar.thisWeek()) }
                    Button(MovementText.t("השבוע שעבר", "Last week", language)) { apply(ReportCalendar.previousWeek()) }
                    Button(MovementText.t("החודש", "This month", language)) { apply(ReportCalendar.thisMonth()) }
                    Button(MovementText.t("החודש שעבר", "Last month", language)) { apply(ReportCalendar.previousMonth()) }
                }

                Section {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .environment(\.locale, language.locale)
            .navigationTitle(MovementText.t("דוח שבועי", "Weekly report", language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(MovementText.t("ביטול", "Cancel", language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(MovementText.t("שתף", "Share", language)) {
                        onShare()
                        dismiss()
                    }
                    .disabled(!canShare)
                }
            }
        }
        .environment(\.layoutDirection, language.layoutDirection)
    }

    private var summary: String {
        if weekCount > ReportCalendar.pageLimit {
            return MovementText.t(
                "הטווח ארוך מדי. אפשר עד \(ReportCalendar.pageLimit) שבועות בדוח אחד.",
                "The range is too long. Up to \(ReportCalendar.pageLimit) weeks per report.",
                language
            )
        }
        if weekCount == 1 {
            return MovementText.t(
                "הדוח יהיה עמוד A4 אחד לרוחב.",
                "The report will be one landscape A4 page.",
                language
            )
        }
        return MovementText.t(
            "הדוח יהיה \(weekCount) עמודים, שבוע אחד בכל עמוד A4 לרוחב.",
            "The report will be \(weekCount) pages, one week per landscape A4 page.",
            language
        )
    }

    private func apply(_ range: (start: Date, end: Date)) {
        start = range.start
        end = range.end
    }
}
