import SwiftUI
import SwiftData

struct DailyReportView: View {
    let day: Date
    
    @Query private var entries: [FoodEntry]
    
    init(day: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        self.day = start
        _entries = Query(
            filter: #Predicate<FoodEntry> { entry in
                entry.date >= start && entry.date < end
            },
            sort: \FoodEntry.date
        )
    }
    
    private var sections: [(type: MealType, entries: [FoodEntry])] {
        MealType.allCases.compactMap { type in
            let matches = entries.filter { $0.mealType == type }
            return matches.isEmpty ? nil : (type, matches)
        }
    }
    
    private var reportText: String {
        var lines = [day.diaryFullTitle()]
        for section in sections {
            lines.append("")
            lines.append(section.type.title)
            for entry in section.entries {
                lines.append("• \(entry.title)")
                if !entry.notes.isEmpty {
                    lines.append("  \(entry.notes)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
    
    var body: some View {
        List {
            ForEach(sections, id: \.type) { section in
                Section(section.type.title) {
                    ForEach(section.entries) { entry in
                        HStack(alignment: .top, spacing: 12) {
                            if let data = entry.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 52, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title)
                                    .font(.headline)
                                if !entry.notes.isEmpty {
                                    Text(entry.notes)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(day.diarySectionTitle())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: reportText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}
