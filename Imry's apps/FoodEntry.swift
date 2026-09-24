import Foundation
import SwiftData
import SwiftUI

enum MealType: Int, Codable, CaseIterable, Identifiable {
    case breakfast = 0
    case morningSnack = 1
    case lunch = 2
    case afternoonSnack = 3
    case dinner = 4
    case nightSnack = 5
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .breakfast: return "ארוחת בוקר"
        case .morningSnack: return "ביניים בוקר"
        case .lunch: return "ארוחת צהריים"
        case .afternoonSnack: return "ביניים צהריים"
        case .dinner: return "ארוחת ערב"
        case .nightSnack: return "ארוחת לילה"
        }
    }
    
    var color: Color {
        switch self {
        case .breakfast: return Color.orange
        case .morningSnack: return Color.yellow
        case .lunch: return Color.green
        case .afternoonSnack: return Color.teal
        case .dinner: return Color.blue
        case .nightSnack: return Color.indigo
        }
    }
}

@Model
final class FoodEntry {
    var title: String
    var notes: String
    var date: Date
    var mealTypeRaw: Int?
    @Attribute(.externalStorage) var imageData: Data?
    
    @Transient
    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw ?? 2) ?? .lunch }
        set { mealTypeRaw = newValue.rawValue }
    }
    
    init(title: String, notes: String, date: Date = Date(), mealType: MealType = .lunch, imageData: Data? = nil) {
        self.title = title
        self.notes = notes
        self.date = date
        self.mealTypeRaw = mealType.rawValue
        self.imageData = imageData
    }
}
