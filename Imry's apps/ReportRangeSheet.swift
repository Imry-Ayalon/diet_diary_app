import SwiftUI

struct ReportRangeSheet: View {
    @Binding var start: Date
    @Binding var end: Date
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
                Section("טווח תאריכים") {
                    DatePicker("מתאריך", selection: $start, displayedComponents: .date)
                    DatePicker("עד תאריך", selection: $end, displayedComponents: .date)
                }
                
                Section("בחירה מהירה") {
                    Button("השבוע") { apply(ReportCalendar.thisWeek()) }
                    Button("השבוע שעבר") { apply(ReportCalendar.previousWeek()) }
                    Button("החודש") { apply(ReportCalendar.thisMonth()) }
                    Button("החודש שעבר") { apply(ReportCalendar.previousMonth()) }
                }
                
                Section {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .environment(\.locale, Locale(identifier: "he_IL"))
            .navigationTitle("דוח שבועי")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ביטול") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("שתף") {
                        onShare()
                        dismiss()
                    }
                    .disabled(!canShare)
                }
            }
        }
    }
    
    private var summary: String {
        if weekCount > ReportCalendar.pageLimit {
            return "הטווח ארוך מדי. אפשר עד \(ReportCalendar.pageLimit) שבועות בדוח אחד."
        }
        if weekCount == 1 {
            return "הדוח יהיה עמוד A4 אחד לרוחב."
        }
        return "הדוח יהיה \(weekCount) עמודים, שבוע אחד בכל עמוד A4 לרוחב."
    }
    
    private func apply(_ range: (start: Date, end: Date)) {
        start = range.start
        end = range.end
    }
}
