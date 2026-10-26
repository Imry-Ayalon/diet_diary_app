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
    @AppStorage("reportIncludesPhotos") private var reportIncludesPhotos = true
    
    private func reportPages(from start: Date, to end: Date, includePhotos: Bool) -> [WeeklyReportPage] {
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
        
        let byDay = Dictionary(grouping: foodEntries) { calendar.startOfDay(for: $0.date) }
        return ReportCalendar.weeks(from: start, to: end).map { days in
            WeeklyReportPage(
                dayNames: dayNames,
                dates: days.map { dateFormatter.string(from: $0) },
                rows: rows.map { type, label in
                    WeeklyReportPage.Row(
                        label: label,
                        cells: days.map { day in
                            let matches = (byDay[calendar.startOfDay(for: day)] ?? [])
                                .filter { $0.mealType == type }
                                .sorted { $0.date < $1.date }
                            return WorkoutReportCollapser.collapse(entries: matches).map { entry in
                                WeeklyReportPage.Item(
                                    title: entry.title,
                                    notes: entry.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                                    imageJPEG: includePhotos ? entry.imageData.flatMap {
                                        PhotoImage.jpeg($0, maxSide: 160, quality: 0.45)
                                    } : nil
                                )
                            }
                        }
                    )
                }
            )
        }
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
                    Button {
                        showingAddMeal = true
                    } label: {
                        Image(systemName: "plus")
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
                ReportRangeSheet(start: $reportStart, end: $reportEnd, includePhotos: $reportIncludesPhotos) {
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
        withAnimation { modelContext.insert(copy) }
        showToast("«\(entry.title)» נוסף להיום")
    }

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                if toastMessage == message { toastMessage = nil }
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
            if let data = entry.imageData, let uiImage = PhotoImage.thumbnail(data, points: 60) {
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
            let pages = reportPages(from: reportStart, to: reportEnd, includePhotos: reportIncludesPhotos)
            let url = try WeeklyReportPDF.file(pages: pages)
            presentShare(url: url)
        } catch {
            showToast("לא הצלחנו ליצור את הדוח")
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
