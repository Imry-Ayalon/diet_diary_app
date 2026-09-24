import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var foodEntries: [FoodEntry]
    
    @State private var showingAddMeal = false
    
    // Sort and group for the CSV
    private var csvURL: URL? {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let recentEntries = foodEntries.filter { $0.date >= sevenDaysAgo }
        
        // Group by day (stripping time)
        let groupedByDay = Dictionary(grouping: recentEntries) { entry -> Date in
            calendar.startOfDay(for: entry.date)
        }
        
        // Sort days descending
        let sortedDays = groupedByDay.keys.sorted(by: >)
        
        var csvString = "תאריך,סוג ארוחה,שם המאכל,הערות\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for day in sortedDays {
            let entriesForDay = groupedByDay[day] ?? []
            // Sort by mealType order (0 to 5)
            let sortedEntries = entriesForDay.sorted { $0.mealType.rawValue < $1.mealType.rawValue }
            
            let dateString = dateFormatter.string(from: day)
            
            for entry in sortedEntries {
                let safeType = entry.mealType.title
                let safeTitle = entry.title.replacingOccurrences(of: ",", with: " ")
                let safeNotes = entry.notes.replacingOccurrences(of: ",", with: " ")
                
                csvString += "\(dateString),\(safeType),\(safeTitle),\(safeNotes)\n"
            }
        }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WeeklyReport.csv")
        var data = Data([0xEF, 0xBB, 0xBF]) // UTF-8 BOM
        if let stringData = csvString.data(using: .utf8) {
            data.append(stringData)
        }
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(foodEntries) { entry in
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
                                    Image(systemName: "fork.knife")
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
                            
                            Text(entry.date, format: .dateTime.day().month().year())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("יומן ארוחות")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let url = csvURL {
                        ShareLink(item: url) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("דוח שבועי")
                            }
                        }
                    }
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
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(foodEntries[index])
            }
        }
    }
}
