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
                    if let imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
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
                        .onChange(of: selectedPhotoItem) { oldValue, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    imageData = data
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(formTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ביטול") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("שמור") {
                        saveMeal()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker(selectedImageData: $imageData)
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
    
    private func saveMeal() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        
        if let existingEntry {
            existingEntry.title = trimmedTitle
            existingEntry.notes = trimmedNotes
            existingEntry.date = selectedDate
            existingEntry.mealType = selectedMealType
            existingEntry.imageData = imageData
        } else {
            let entry = FoodEntry(
                title: trimmedTitle,
                notes: trimmedNotes,
                date: selectedDate,
                mealType: selectedMealType,
                imageData: imageData
            )
            modelContext.insert(entry)
        }
        dismiss()
    }
}
