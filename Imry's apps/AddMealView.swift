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
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("פרטי ארוחה")) {
                    DatePicker("תאריך", selection: $selectedDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "he_IL"))
                    
                    Picker("סוג ארוחה", selection: $selectedMealType) {
                        ForEach(MealType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    
                    TextField("שם המאכל", text: $title)
                    TextField("הערות או מרכיבים", text: $notes)
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
            .navigationTitle("הוסף ארוחה")
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
    
    private func saveMeal() {
        let entry = FoodEntry(
            title: title.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces),
            date: selectedDate,
            mealType: selectedMealType,
            imageData: imageData
        )
        modelContext.insert(entry)
        dismiss()
    }
}
