import SwiftUI
import SwiftData
import PhotosUI

struct AddMealView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedMealType: MealType = .lunch
    @State private var imageData: Data?
    
    @State private var isShowingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var recognition = Recognition()
    @State private var isSaving = false
    
    @Query(sort: \FoodEntry.date, order: .reverse) private var foodEntries: [FoodEntry]
    
    private let existingEntry: FoodEntry?
    
    init(entry: FoodEntry? = nil) {
        existingEntry = entry
        _title = State(initialValue: entry?.title ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _selectedDate = State(initialValue: entry?.date ?? Date())
        _selectedMealType = State(initialValue: entry?.mealType ?? .lunch)
        _imageData = State(initialValue: entry?.imageData)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(isWorkout ? "פרטי אימון" : "פרטי ארוחה")) {
                    DatePicker("תאריך", selection: $selectedDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "he_IL"))
                    
                    Picker("סוג", selection: $selectedMealType) {
                        ForEach(MealType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    
                    TextField(isWorkout ? "תיאור האימון" : "שם המאכל", text: $title)
                    TextField(isWorkout ? "הערות" : "הערות או מרכיבים", text: $notes)
                }
                
                Section(header: Text("תמונה")) {
                    if let imageData, let uiImage = PhotoImage.thumbnail(imageData, points: 400) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    recognitionRow
                    
                    HStack {
                        Button(action: {
                            isShowingCamera = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("צלם")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("גלריה")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .onChange(of: selectedPhotoItem) { _, newValue in
                            Task {
                                guard let data = try? await newValue?.loadTransferable(type: Data.self) else { return }
                                imageData = await Task.detached(priority: .userInitiated) {
                                    PhotoImage.jpeg(data, maxSide: 1024, quality: 0.5)
                                }.value
                            }
                        }
                    }
                }
            }
            .navigationTitle(formTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ביטול") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("שמור", action: saveMeal)
                        .disabled(isSaving || trimmed(title).isEmpty)
                }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker(selectedImageData: $imageData)
            }
            .onChange(of: imageData) { _, newValue in
                recognizeFood(in: newValue)
            }
            .onChange(of: selectedMealType) { oldValue, newValue in
                if newValue == .workout || oldValue == .workout {
                    recognizeFood(in: imageData)
                }
            }
        }
    }
    
    @ViewBuilder
    private var recognitionRow: some View {
        if !isWorkout, imageData != nil, let status = recognition.status {
            HStack {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let suggestion = recognition.suggestion, trimmed(title) != suggestion {
                    Button("השתמש") { title = suggestion }
                        .font(.footnote)
                }
            }
        }
    }
    
    private var isWorkout: Bool {
        selectedMealType == .workout
    }
    
    private var isEditing: Bool {
        existingEntry != nil
    }
    
    private var formTitle: String {
        if isEditing {
            return isWorkout ? "עריכת אימון" : "עריכת ארוחה"
        }
        return isWorkout ? "הוסף אימון" : "הוסף ארוחה"
    }
    
    private func recognizeFood(in imageData: Data?) {
        recognition.requestID += 1
        let requestID = recognition.requestID
        recognition.suggestion = nil
        recognition.featurePrint = nil
        
        guard !isWorkout, let imageData else {
            recognition.status = nil
            return
        }
        
        recognition.status = "מזהה…"
        let meals = loggedMeals()
        Task.detached(priority: .userInitiated) {
            let result = FoodRecognizer.recognize(imageData: imageData, meals: meals)
            await MainActor.run {
                apply(result, requestID: requestID)
            }
        }
    }
    
    private func loggedMeals() -> [FoodRecognizer.LoggedMeal] {
        let excludedID = existingEntry?.persistentModelID
        return foodEntries.compactMap { entry in
            guard entry.mealType != .workout else { return nil }
            if let excludedID, entry.persistentModelID == excludedID { return nil }
            guard entry.imageData != nil || entry.featurePrint != nil else { return nil }
            return FoodRecognizer.LoggedMeal(
                id: entry.persistentModelID,
                title: entry.title,
                featurePrint: entry.featurePrint,
                imageData: entry.featurePrint == nil ? entry.imageData : nil
            )
        }
    }
    
    private func apply(_ result: FoodRecognizer.Result, requestID: Int) {
        guard requestID == recognition.requestID else { return }
        recognition.featurePrint = result.featurePrint
        saveNewPrints(result.printsToSave)
        
        guard let name = result.name else {
            recognition.suggestion = nil
            recognition.status = "לא זוהה"
            return
        }
        
        recognition.suggestion = name
        recognition.status = "זיהוי: \(name)"
        if trimmed(title).isEmpty {
            title = name
        }
    }
    
    private func saveNewPrints(_ prints: [(PersistentIdentifier, Data)]) {
        for (id, data) in prints {
            guard let entry = foodEntries.first(where: { $0.persistentModelID == id }),
                  entry.featurePrint == nil else { continue }
            entry.featurePrint = data
        }
    }
    
    private func saveMeal() {
        guard !isSaving else { return }
        isSaving = true
        
        let draft = MealDraft(
            title: trimmed(title),
            notes: trimmed(notes),
            date: selectedDate,
            mealType: selectedMealType,
            imageData: imageData
        )
        let preparedPrint = featurePrintReadyToStore(for: draft.imageData)
        
        Task {
            let featurePrint = await preparedPrint.resolve()
            store(draft, featurePrint: featurePrint)
            dismiss()
        }
    }
    
    private func featurePrintReadyToStore(for imageData: Data?) -> PreparedPrint {
        guard let imageData else { return .none }
        if let featurePrint = recognition.featurePrint { return .ready(featurePrint) }
        if let existingEntry, existingEntry.imageData == imageData, let featurePrint = existingEntry.featurePrint {
            return .ready(featurePrint)
        }
        return .needsCompute(imageData)
    }
    
    private func store(_ draft: MealDraft, featurePrint: Data?) {
        if let existingEntry {
            existingEntry.title = draft.title
            existingEntry.notes = draft.notes
            existingEntry.date = draft.date
            existingEntry.mealType = draft.mealType
            existingEntry.imageData = draft.imageData
            existingEntry.featurePrint = featurePrint
        } else {
            modelContext.insert(FoodEntry(
                title: draft.title,
                notes: draft.notes,
                date: draft.date,
                mealType: draft.mealType,
                imageData: draft.imageData,
                featurePrint: featurePrint
            ))
        }
    }
    
    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct Recognition {
    var requestID = 0
    var status: String?
    var suggestion: String?
    var featurePrint: Data?
}

private struct MealDraft {
    let title: String
    let notes: String
    let date: Date
    let mealType: MealType
    let imageData: Data?
}

private enum PreparedPrint {
    case none
    case ready(Data)
    case needsCompute(Data)
    
    func resolve() async -> Data? {
        switch self {
        case .none:
            return nil
        case .ready(let data):
            return data
        case .needsCompute(let imageData):
            return await Task.detached(priority: .userInitiated) {
                FoodRecognizer.featurePrintData(for: imageData)
            }.value
        }
    }
}
