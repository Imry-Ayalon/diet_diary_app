import SwiftUI
import SwiftData
import MapKit
import PhotosUI

struct RideHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.movementLanguage) private var language
    @Query(sort: \Ride.date, order: .reverse) private var rides: [Ride]

    @AppStorage("riderWeightKg") private var weightKg = 0.0
    @AppStorage("movementLanguage") private var languageRaw = MovementLanguage.hebrew.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @State private var session = RideSession()
    @State private var sessionReady = false
    @State private var showingWeight = false
    @State private var showingReport = false
    @State private var showingPrivacy = false
    @State private var showingInstructions = false
    @State private var showingFAQ = false
    @State private var confirmDiscard = false
    @State private var saveError: String?
    @State private var reportStart = ReportCalendar.thisWeek().start
    @State private var reportEnd = ReportCalendar.thisWeek().end
    @State private var reportError = false

    let diary: ModelContainer

    var body: some View {
        NavigationStack {
            Group {
                if !sessionReady {
                    Color.clear
                } else if session.phase == .idle {
                    history
                } else {
                    activeRide
                }
            }
            .onAppear {
                session.restoreIfNeeded()
                sessionReady = true
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    session.saveProgress()
                }
            }
            .navigationTitle("movement")
            .toolbar {
                if session.phase == .idle {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showingWeight = true
                            } label: {
                                Label(MovementText.t("משקל", "Weight", language), systemImage: "scalemass")
                            }
                            Button {
                                reportStart = ReportCalendar.thisWeek().start
                                reportEnd = ReportCalendar.thisWeek().end
                                showingReport = true
                            } label: {
                                Label(MovementText.t("דוח שבועי", "Weekly report", language), systemImage: "doc.richtext")
                            }
                            Menu {
                                ForEach(MovementLanguage.allCases) { option in
                                    Button {
                                        languageRaw = option.rawValue
                                    } label: {
                                        HStack {
                                            Text(option.menuLabel)
                                            if option == language {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label(MovementText.t("שפה", "Language", language), systemImage: "globe")
                            }
                            Divider()
                            Button {
                                showingInstructions = true
                            } label: {
                                Label(MovementText.t("הוראות", "Instructions", language), systemImage: "list.bullet.rectangle")
                            }
                            Button {
                                showingFAQ = true
                            } label: {
                                Label(MovementText.t("שאלות נפוצות", "FAQ", language), systemImage: "questionmark.circle")
                            }
                            Button {
                                showingPrivacy = true
                            } label: {
                                Label(MovementText.t("פרטיות", "Privacy", language), systemImage: "hand.raised")
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                        .accessibilityLabel(MovementText.t("תפריט", "Menu", language))
                    }
                }
            }
            .sheet(isPresented: $showingWeight) {
                WeightSheet(weightKg: $weightKg, language: language)
            }
            .sheet(isPresented: $showingReport) {
                RideReportRangeSheet(
                    start: $reportStart,
                    end: $reportEnd,
                    language: language
                ) {
                    Task { await shareWeeklyReport() }
                }
            }
            .sheet(isPresented: $showingPrivacy) {
                DocumentSheet(
                    title: MovementText.t("פרטיות", "Privacy", language),
                    bodyText: MovementText.privacy(language),
                    language: language
                )
            }
            .sheet(isPresented: $showingInstructions) {
                DocumentSheet(
                    title: MovementText.t("הוראות", "Instructions", language),
                    bodyText: MovementText.instructions(language),
                    language: language
                )
            }
            .sheet(isPresented: $showingFAQ) {
                DocumentSheet(
                    title: MovementText.t("שאלות נפוצות", "FAQ", language),
                    bodyText: MovementText.faq(language),
                    language: language
                )
            }
            .alert(MovementText.t("לא נשמר", "Not saved", language), isPresented: saveErrorPresented) {
                Button(MovementText.t("בסדר", "OK", language), role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
            .alert(MovementText.t("לא נוצר דוח", "Report failed", language), isPresented: $reportError) {
                Button(MovementText.t("בסדר", "OK", language), role: .cancel) {}
            }
            .confirmationDialog(
                MovementText.t(
                    "למחוק את \(session.kind.definite(language))?",
                    "Delete \(session.kind.definite(language))?",
                    language
                ),
                isPresented: $confirmDiscard,
                titleVisibility: .visible
            ) {
                Button(MovementText.t("מחק", "Delete", language), role: .destructive) { session.discard() }
                Button(session.kind.resume(language), role: .cancel) {}
            } message: {
                Text(MovementText.t(
                    "\(session.kind.definite(language)) לא תישמר.",
                    "\(session.kind.definite(language).capitalized) will not be saved.",
                    language
                ))
            }
        }
    }

    private var ridesByDay: [(day: Date, rides: [Ride])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: rides) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            (day, (grouped[day] ?? []).sorted { $0.date > $1.date })
        }
    }

    private var history: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    startButton(.ride)
                    startButton(.run)
                    startButton(.walk)
                }
                .listRowInsets(EdgeInsets())
                .padding()

                if session.locationDenied {
                    Text(MovementText.t(
                        "כדי למדוד רכיבה, ריצה או הליכה צריך לאשר מיקום בהגדרות.",
                        "To measure a ride, run, or walk, allow location in Settings.",
                        language
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            if rides.isEmpty {
                Section(MovementText.t("פעילויות", "Activities", language)) {
                    Text(MovementText.t("עדיין אין פעילויות", "No activities yet", language))
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(ridesByDay, id: \.day) { group in
                    Section(dayHeader(group.day)) {
                        ForEach(group.rides) { ride in
                            NavigationLink {
                                RideDetailView(ride: ride, diary: diary)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(ride.kind.label(language), systemImage: ride.kind.symbol)
                                        .font(.headline)
                                    Text(ride.date.formatted(date: .omitted, time: .shortened))
                                        .font(.subheadline)
                                    Text(RideSummary.notes(
                                        distanceMeters: ride.distanceMeters,
                                        movingSeconds: ride.movingSeconds,
                                        ascentMeters: ride.ascentMeters ?? 0,
                                        calories: ride.calories,
                                        language: language
                                    ))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button(MovementText.t("מחק", "Delete", language), role: .destructive) {
                                    delete(ride)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func dayHeader(_ day: Date) -> String {
        day.formatted(
            Date.FormatStyle(date: .complete, time: .omitted)
                .locale(language.locale)
        )
    }

    private func startButton(_ kind: ActivityKind) -> some View {
        Button {
            session.start(kind)
        } label: {
            Label(kind.label(language), systemImage: kind.symbol)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint(for: kind))
    }

    private func tint(for kind: ActivityKind) -> Color {
        switch kind {
        case .ride: .teal
        case .run: .orange
        case .walk: .green
        }
    }

    private var activeRide: some View {
        VStack(spacing: 16) {
            RideMap(track: session.track, followsUser: true)
                .frame(maxHeight: .infinity)

            VStack(spacing: 6) {
                Label(phaseTitle, systemImage: session.kind.symbol)
                    .font(.headline)
                Text(distanceLiveText)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Text("\(RideSummary.clock(session.movingSeconds)) · \(speedLiveText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(ascentLiveText) · \(calorieText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button(MovementText.t("מחק", "Delete", language)) { confirmDiscard = true }
                    .buttonStyle(.bordered)
                    .tint(.red)
                if session.phase == .breakPause {
                    Button(MovementText.t("המשך", "Resume", language), action: session.resumeFromBreak)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(MovementText.t("הפסקה", "Pause", language), action: session.pauseForBreak)
                        .buttonStyle(.bordered)
                }
                Button(MovementText.t("סיום", "Finish", language), action: finishRide)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.bottom)
        }
    }

    private var phaseTitle: String {
        switch session.phase {
        case .idle: return ""
        case .riding: return session.kind.moving(language)
        case .trafficPause: return MovementText.t("עצירה ברמזור", "Traffic stop", language)
        case .breakPause: return MovementText.t("הפסקה", "Paused", language)
        }
    }

    private var distanceLiveText: String {
        language == .english
            ? String(format: "%.2f km", session.distanceMeters / 1000)
            : String(format: "%.2f ק״מ", session.distanceMeters / 1000)
    }

    private var speedLiveText: String {
        language == .english
            ? String(format: "%.0f km/h", session.speedMetersPerSecond * 3.6)
            : String(format: "%.0f קמ״ש", session.speedMetersPerSecond * 3.6)
    }

    private var ascentLiveText: String {
        let meters = Int(session.ascentMeters.rounded())
        return language == .english ? "\(meters) m ascent" : "\(meters) מ׳ עלייה"
    }

    private var calorieText: String {
        guard let calories = RideCalories.estimate(
            distanceMeters: session.distanceMeters,
            movingSeconds: session.movingSeconds,
            weightKg: weightKg,
            kind: session.kind
        ) else {
            if weightKg > 0 {
                return MovementText.t("כ-0 קק״ל", "~0 kcal", language)
            }
            return MovementText.t("בלי משקל", "No weight", language)
        }
        return MovementText.t("כ-\(calories) קק״ל", "~\(calories) kcal", language)
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }

    private func finishRide() {
        guard let snapshot = session.finish() else { return }
        let finished = Date()
        let calories = RideCalories.estimate(
            distanceMeters: snapshot.distanceMeters,
            movingSeconds: snapshot.movingSeconds,
            weightKg: weightKg,
            kind: snapshot.kind
        )
        modelContext.insert(Ride(
            date: finished,
            distanceMeters: snapshot.distanceMeters,
            movingSeconds: snapshot.movingSeconds,
            calories: calories,
            ascentMeters: snapshot.ascentMeters,
            maxSpeedMetersPerSecond: snapshot.maxSpeedMetersPerSecond,
            kind: snapshot.kind,
            track: snapshot.track
        ))
        try? modelContext.save()
        do {
            try DiaryWorkout.add(
                snapshot.kind,
                on: finished,
                distanceMeters: snapshot.distanceMeters,
                movingSeconds: snapshot.movingSeconds,
                ascentMeters: snapshot.ascentMeters,
                calories: calories,
                container: diary
            )
        } catch {
            saveError = MovementText.t(
                "\(snapshot.kind.definite(language)) נשמרה כאן, אבל לא נוספה ליומן.",
                "\(snapshot.kind.definite(language).capitalized) was saved here, but not added to the diary.",
                language
            )
        }
    }

    private func delete(_ ride: Ride) {
        DiaryWorkout.remove(ride.kind, on: ride.date, container: diary)
        modelContext.delete(ride)
        try? modelContext.save()
    }

    @MainActor
    private func shareWeeklyReport() async {
        let pages = RideWeeklyReportPDF.pages(
            from: rides,
            start: reportStart,
            end: reportEnd,
            language: language
        )
        do {
            let url = try RideWeeklyReportPDF.file(pages: pages, language: language)
            presentShare(url: url)
        } catch {
            reportError = true
        }
    }
}

private struct RideMap: View {
    let track: [TrackPoint]
    var followsUser = false

    var body: some View {
        Map(position: .constant(camera)) {
            UserAnnotation()
            if track.count > 1 {
                MapPolyline(coordinates: track.map(\.coordinate))
                    .stroke(.teal, lineWidth: 5)
            }
        }
        .mapStyle(.standard)
    }

    private var camera: MapCameraPosition {
        if followsUser {
            return .userLocation(fallback: .automatic)
        }
        guard let region = track.routeRegion() else { return .automatic }
        return .region(region)
    }
}

private struct RideDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.movementLanguage) private var language

    let ride: Ride
    let diary: ModelContainer

    @State private var isSharing = false
    @State private var confirmDelete = false
    @State private var shareError = false
    @State private var photoItem: PhotosPickerItem?
    @State private var pickingPhoto = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RideMap(track: ride.track)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                Text(RideSummary.notes(
                    distanceMeters: ride.distanceMeters,
                    movingSeconds: ride.movingSeconds,
                    ascentMeters: ride.ascentMeters ?? 0,
                    calories: ride.calories,
                    language: language
                ))
                .font(.headline)
                Text(speedSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .bottom])
        }
        .navigationTitle(ride.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await share(backgroundPhoto: nil) }
                    } label: {
                        Label(
                            MovementText.t("שתף עם מפה", "Share with map", language),
                            systemImage: "map"
                        )
                    }
                    Button {
                        pickingPhoto = true
                    } label: {
                        Label(
                            MovementText.t("שתף עם תמונה", "Share with photo", language),
                            systemImage: "photo"
                        )
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(isSharing)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(MovementText.t("מחק", "Delete", language), role: .destructive) { confirmDelete = true }
            }
        }
        .photosPicker(isPresented: $pickingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                await shareSelectedPhoto(item)
                photoItem = nil
            }
        }
        .confirmationDialog(
            MovementText.t(
                "למחוק את \(ride.kind.definite(language))?",
                "Delete \(ride.kind.definite(language))?",
                language
            ),
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(MovementText.t("מחק", "Delete", language), role: .destructive) { remove() }
            Button(MovementText.t("ביטול", "Cancel", language), role: .cancel) {}
        } message: {
            Text(MovementText.t(
                "\(ride.kind.definite(language)) תוסר גם מיומן הארוחות.",
                "\(ride.kind.definite(language).capitalized) will also be removed from the meal diary.",
                language
            ))
        }
        .alert(MovementText.t("לא נוצרה תמונה", "Image failed", language), isPresented: $shareError) {
            Button(MovementText.t("בסדר", "OK", language), role: .cancel) {}
        }
    }

    private var maxSpeed: String {
        guard let speed = ride.maxSpeedMetersPerSecond, speed > 0 else { return "—" }
        return self.speed(speed * 3.6)
    }

    private var speedSummary: String {
        let average = speed(RideSummary.averageKilometersPerHour(
            distanceMeters: ride.distanceMeters,
            movingSeconds: ride.movingSeconds
        ))
        return MovementText.t(
            "ממוצע \(average) · מרבי \(maxSpeed)",
            "Avg \(average) · Max \(maxSpeed)",
            language
        )
    }

    private func speed(_ kilometersPerHour: Double) -> String {
        language == .english
            ? String(format: "%.1f km/h", kilometersPerHour)
            : String(format: "%.1f קמ״ש", kilometersPerHour)
    }

    private func shareSelectedPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            shareError = true
            return
        }
        await share(backgroundPhoto: image)
    }

    private func share(backgroundPhoto: UIImage?) async {
        isSharing = true
        defer { isSharing = false }
        let stats = RidePoster.Stats(
            kind: ride.kind,
            date: ride.date,
            distanceMeters: ride.distanceMeters,
            movingSeconds: ride.movingSeconds,
            ascentMeters: ride.ascentMeters ?? 0,
            maxSpeedMetersPerSecond: ride.maxSpeedMetersPerSecond ?? 0,
            track: ride.track,
            language: language
        )
        guard let url = await RidePoster.jpeg(stats, backgroundPhoto: backgroundPhoto) else {
            shareError = true
            return
        }
        presentShare(url: url)
    }

    private func remove() {
        DiaryWorkout.remove(ride.kind, on: ride.date, container: diary)
        modelContext.delete(ride)
        try? modelContext.save()
        dismiss()
    }
}

private struct WeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var weightKg: Double
    let language: MovementLanguage
    @State private var text: String

    init(weightKg: Binding<Double>, language: MovementLanguage) {
        _weightKg = weightKg
        self.language = language
        let current = weightKg.wrappedValue
        _text = State(initialValue: current > 0 ? String(format: "%.0f", current) : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(MovementText.t("משקל בקילוגרם", "Weight in kilograms", language), text: $text)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle(MovementText.t("משקל", "Weight", language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(MovementText.t("ביטול", "Cancel", language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(MovementText.t("שמור", "Save", language)) {
                        let normalized = text.replacingOccurrences(of: ",", with: ".")
                        weightKg = Double(normalized) ?? 0
                        dismiss()
                    }
                }
            }
        }
        .environment(\.layoutDirection, language.layoutDirection)
        .presentationDetents([.medium])
    }
}

private struct DocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let bodyText: String
    let language: MovementLanguage

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(bodyText)
                    .frame(maxWidth: .infinity, alignment: language == .hebrew ? .trailing : .leading)
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(MovementText.t("סגור", "Close", language)) { dismiss() }
                }
            }
        }
        .environment(\.layoutDirection, language.layoutDirection)
    }
}
