import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var foodEntries: [FoodEntry]
    
    @State private var showingAddMeal = false
    @State private var entryToEdit: FoodEntry?
    @State private var pendingTapID: PersistentIdentifier?
    @State private var toastMessage: String?
    @State private var isSharingReport = false
    @State private var showingReportRange = false
    @State private var shareAfterRangeDismiss = false
    @State private var reportStart = ReportCalendar.thisWeek().start
    @State private var reportEnd = ReportCalendar.thisWeek().end
    
    private func reportPages(from start: Date, to end: Date) -> [String] {
        let calendar = ReportCalendar.calendar
        let dayNames = ["ראשון", "שני", "שלישי", "רביעי", "חמישי", "שישי", "שבת"]
        let rows: [(MealType, String)] = [
            (.breakfast, "ארוחת בוקר"),
            (.morningSnack, "ביניים בוקר"),
            (.lunch, "ארוחת צהריים"),
            (.afternoonSnack, "ביניים צהריים"),
            (.dinner, "ארוחת ערב"),
            (.nightSnack, "ארוחת לילה"),
            (.workout, "ספורט")
        ]
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = calendar
        dateFormatter.dateFormat = "d/MM/yy"
        
        return ReportCalendar.weeks(from: start, to: end).map { days in
            var html = """
            <!DOCTYPE html>
            <html lang="he" dir="rtl">
            <head>
            <meta charset="utf-8">
            <style>
              * { box-sizing: border-box; }
              html, body { margin: 0; padding: 0; width: 842px; height: 595px; overflow: hidden; background: white; }
              table { width: 842px; height: 595px; border-collapse: collapse; table-layout: fixed; font-family: -apple-system, sans-serif; font-size: 8px; }
              th, td { border: 1px solid #ccc; padding: 2px; vertical-align: top; overflow: hidden; }
              .label { width: 74px; font-weight: 700; background: #f7f7f7; }
              .head { height: 22px; background: #f3f3f3; text-align: center; font-size: 10px; }
              .date { height: 18px; text-align: center; }
              img { display: block; width: 58px; height: 26px; object-fit: cover; border-radius: 3px; margin-bottom: 1px; }
              .content, .notes { max-height: 18px; line-height: 9px; overflow: hidden; }
              .entry + .entry { margin-top: 2px; }
            </style>
            </head>
            <body>
            <table>
            <tr class="head"><th class="label"></th>
            """
            for name in dayNames {
                html += "<th>\(name)</th>"
            }
            html += "</tr><tr class=\"date\"><th class=\"label\">תאריך</th>"
            for day in days {
                html += "<td>\(dateFormatter.string(from: day))</td>"
            }
            html += "</tr>"
            for (type, label) in rows {
                html += "<tr><th class=\"label\">\(label)</th>"
                for day in days {
                    let matches = foodEntries
                        .filter { calendar.isDate($0.date, inSameDayAs: day) && $0.mealType == type }
                        .sorted { $0.date < $1.date }
                    html += "<td>\(reportCell(matches))</td>"
                }
                html += "</tr>"
            }
            html += "</table></body></html>"
            return html
        }
    }
    
    private func reportCell(_ entries: [FoodEntry]) -> String {
        entries.map { entry in
            var parts: [String] = []
            if let data = entry.imageData,
               let image = UIImage(data: data),
               let jpeg = reportJPEG(image) {
                parts.append("<img src=\"data:image/jpeg;base64,\(jpeg.base64EncodedString())\" alt=\"\">")
            }
            parts.append("<div>תוכן : \(reportEscape(entry.title))</div>")
            let notes = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty {
                parts.append("<div>הערות : \(reportEscape(notes))</div>")
            }
            return "<div class=\"entry\">\(parts.joined())</div>"
        }.joined()
    }
    
    private func reportEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }
    
    private func reportJPEG(_ image: UIImage) -> Data? {
        let maxWidth: CGFloat = 120
        let maxHeight: CGFloat = 56
        let widthRatio = maxWidth / image.size.width
        let heightRatio = maxHeight / image.size.height
        let ratio = min(widthRatio, heightRatio, 1)
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: size)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return scaled.jpegData(compressionQuality: 0.45)
    }
    
    private var groupedDays: [(day: Date, entries: [FoodEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: foodEntries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        return grouped.keys.sorted(by: >).map { day in
            let entries = (grouped[day] ?? []).sorted {
                if $0.mealType.rawValue != $1.mealType.rawValue {
                    return $0.mealType.rawValue < $1.mealType.rawValue
                }
                return $0.date < $1.date
            }
            return (day, entries)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedDays, id: \.day) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            entryRow(entry)
                        }
                        .onDelete { offsets in
                            deleteItems(in: group.entries, at: offsets)
                        }
                    } header: {
                        HStack {
                            Text(group.day.diarySectionTitle())
                            Spacer()
                            NavigationLink {
                                DailyReportView(day: group.day)
                            } label: {
                                Text("דוח יומי")
                                    .font(.caption)
                            }
                        }
                        .textCase(nil)
                    }
                }
            }
            .navigationTitle("יומן ארוחות")
            .navigationSubtitle("הקשה לעריכה, הקשה כפולה מוסיפה להיום")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingReportRange = true
                    } label: {
                        if isSharingReport {
                            ProgressView()
                        } else {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("דוח שבועי")
                            }
                        }
                    }
                    .disabled(isSharingReport)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingAddMeal = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddMeal) {
                AddMealView()
            }
            .sheet(isPresented: $showingReportRange, onDismiss: {
                guard shareAfterRangeDismiss else { return }
                shareAfterRangeDismiss = false
                Task { await shareWeeklyReport() }
            }) {
                ReportRangeSheet(start: $reportStart, end: $reportEnd) {
                    shareAfterRangeDismiss = true
                }
            }
            .sheet(item: $entryToEdit) { entry in
                AddMealView(entry: entry)
            }
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    private func duplicateMeal(_ entry: FoodEntry) {
        let copy = FoodEntry(
            title: entry.title,
            notes: entry.notes,
            date: Date(),
            mealType: entry.mealType,
            imageData: entry.imageData,
            featurePrint: entry.featurePrint
        )
        withAnimation {
            modelContext.insert(copy)
            toastMessage = "«\(entry.title)» נוסף להיום"
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                if toastMessage == "«\(entry.title)» נוסף להיום" {
                    toastMessage = nil
                }
            }
        }
    }
    
    private func deleteItems(in entries: [FoodEntry], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(entries[index])
            }
        }
    }
    
    private func entryRow(_ entry: FoodEntry) -> some View {
        HStack(spacing: 12) {
            if let data = entry.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 2)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(entry.mealType.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: entry.mealType.symbolName)
                            .foregroundColor(entry.mealType.color)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.mealType.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(entry.mealType.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(entry.mealType.color.opacity(0.1))
                    .clipShape(Capsule())
                
                Text(entry.title)
                    .font(.headline)
                
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            handleRowTap(entry)
        }
        .accessibilityHint("הקשה לעריכה. הקשה כפולה מוסיפה את הרשומה שוב להיום")
    }
    
    private func shareWeeklyReport() async {
        isSharingReport = true
        defer { isSharingReport = false }
        do {
            let pages = reportPages(from: reportStart, to: reportEnd)
            let url = try await WeeklyReportPDF.file(pages: pages)
            presentShareSheet(url: url)
        } catch {
            withAnimation {
                toastMessage = "לא הצלחנו ליצור את הדוח"
            }
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                if toastMessage == "לא הצלחנו ליצור את הדוח" {
                    toastMessage = nil
                }
            }
        }
    }
    
    private func handleRowTap(_ entry: FoodEntry) {
        let id = entry.persistentModelID
        if pendingTapID == id {
            pendingTapID = nil
            duplicateMeal(entry)
            return
        }
        
        pendingTapID = id
        Task {
            try? await Task.sleep(for: .milliseconds(280))
            if pendingTapID == id {
                pendingTapID = nil
                entryToEdit = entry
            }
        }
    }
}
