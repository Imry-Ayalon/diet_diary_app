import SwiftUI
import SwiftData
import MapKit

struct RideHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Ride.date, order: .reverse) private var rides: [Ride]

    @AppStorage("riderWeightKg") private var weightKg = 0.0
    @State private var session = RideSession()
    @State private var showingWeight = false
    @State private var confirmDiscard = false
    @State private var saveError: String?

    let diary: ModelContainer

    var body: some View {
        NavigationStack {
            Group {
                if session.phase == .idle {
                    history
                } else {
                    activeRide
                }
            }
            .navigationTitle("רכיבה")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("משקל") { showingWeight = true }
                }
            }
            .sheet(isPresented: $showingWeight) {
                WeightSheet(weightKg: $weightKg)
            }
            .alert("לא נשמר", isPresented: saveErrorPresented) {
                Button("בסדר", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
            .confirmationDialog("למחוק את הרכיבה?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("מחק", role: .destructive) { session.discard() }
                Button("המשך לרכוב", role: .cancel) {}
            } message: {
                Text("הרכיבה לא תישמר.")
            }
        }
    }

    private var history: some View {
        List {
            Section {
                Button(action: session.start) {
                    Label("התחל", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .padding()

                if session.locationDenied {
                    Text("כדי למדוד רכיבה צריך לאשר מיקום בהגדרות.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("רכיבות") {
                if rides.isEmpty {
                    Text("עדיין אין רכיבות")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rides) { ride in
                        NavigationLink {
                            RideDetailView(ride: ride, diary: diary)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ride.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)
                                Text(RideSummary.notes(
                                    distanceMeters: ride.distanceMeters,
                                    movingSeconds: ride.movingSeconds,
                                    ascentMeters: ride.ascentMeters ?? 0,
                                    calories: ride.calories
                                ))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button("מחק", role: .destructive) {
                                delete(ride)
                            }
                        }
                    }
                }
            }
        }
    }

    private var activeRide: some View {
        VStack(spacing: 16) {
            RideMap(track: session.track, followsUser: true)
                .frame(maxHeight: .infinity)

            VStack(spacing: 6) {
                Text(phaseTitle)
                    .font(.headline)
                Text(String(format: "%.2f ק״מ", session.distanceMeters / 1000))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Text("\(RideSummary.clock(session.movingSeconds)) · \(String(format: "%.0f קמ״ש", session.speedMetersPerSecond * 3.6))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(Int(session.ascentMeters.rounded())) מ׳ עלייה · \(calorieText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("מחק") { confirmDiscard = true }
                    .buttonStyle(.bordered)
                    .tint(.red)
                if session.phase == .breakPause {
                    Button("המשך", action: session.resumeFromBreak)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("הפסקה", action: session.pauseForBreak)
                        .buttonStyle(.bordered)
                }
                Button("סיום", action: finishRide)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.bottom)
        }
    }

    private var phaseTitle: String {
        switch session.phase {
        case .idle: return ""
        case .riding: return "רוכב"
        case .trafficPause: return "עצירה ברמזור"
        case .breakPause: return "הפסקה"
        }
    }

    private var calorieText: String {
        guard let calories = RideCalories.estimate(
            distanceMeters: session.distanceMeters,
            movingSeconds: session.movingSeconds,
            weightKg: weightKg
        ) else {
            return weightKg > 0 ? "כ-0 קק״ל" : "בלי משקל"
        }
        return "כ-\(calories) קק״ל"
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
            weightKg: weightKg
        )
        modelContext.insert(Ride(
            date: finished,
            distanceMeters: snapshot.distanceMeters,
            movingSeconds: snapshot.movingSeconds,
            calories: calories,
            ascentMeters: snapshot.ascentMeters,
            maxSpeedMetersPerSecond: snapshot.maxSpeedMetersPerSecond,
            track: snapshot.track
        ))
        try? modelContext.save()
        do {
            try DiaryWorkout.addRide(
                on: finished,
                distanceMeters: snapshot.distanceMeters,
                movingSeconds: snapshot.movingSeconds,
                ascentMeters: snapshot.ascentMeters,
                calories: calories,
                container: diary
            )
        } catch {
            saveError = "הרכיבה נשמרה כאן, אבל לא נוספה ליומן."
        }
    }

    private func delete(_ ride: Ride) {
        DiaryWorkout.removeRide(on: ride.date, container: diary)
        modelContext.delete(ride)
        try? modelContext.save()
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

    let ride: Ride
    let diary: ModelContainer

    @State private var isSharing = false
    @State private var confirmDelete = false
    @State private var shareError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RideMap(track: ride.track)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                Text(RideSummary.notes(
                    distanceMeters: ride.distanceMeters,
                    movingSeconds: ride.movingSeconds,
                    ascentMeters: ride.ascentMeters ?? 0,
                    calories: ride.calories
                ))
                .font(.headline)
                Text("ממוצע \(speed(RideSummary.averageKilometersPerHour(distanceMeters: ride.distanceMeters, movingSeconds: ride.movingSeconds))) · מרבי \(maxSpeed)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .bottom])
        }
        .navigationTitle(ride.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await share() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(isSharing)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("מחק", role: .destructive) { confirmDelete = true }
            }
        }
        .confirmationDialog("למחוק את הרכיבה?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("מחק", role: .destructive) { remove() }
            Button("ביטול", role: .cancel) {}
        } message: {
            Text("הרכיבה תוסר גם מיומן הארוחות.")
        }
        .alert("לא נוצרה תמונה", isPresented: $shareError) {
            Button("בסדר", role: .cancel) {}
        }
    }

    private var maxSpeed: String {
        guard let speed = ride.maxSpeedMetersPerSecond, speed > 0 else { return "—" }
        return self.speed(speed * 3.6)
    }

    private func speed(_ kilometersPerHour: Double) -> String {
        String(format: "%.1f קמ״ש", kilometersPerHour)
    }

    private func share() async {
        isSharing = true
        defer { isSharing = false }
        let stats = RidePoster.Stats(
            date: ride.date,
            distanceMeters: ride.distanceMeters,
            movingSeconds: ride.movingSeconds,
            ascentMeters: ride.ascentMeters ?? 0,
            maxSpeedMetersPerSecond: ride.maxSpeedMetersPerSecond ?? 0,
            track: ride.track
        )
        guard let url = await RidePoster.jpeg(stats) else {
            shareError = true
            return
        }
        presentRideShare(url: url)
    }

    private func remove() {
        DiaryWorkout.removeRide(on: ride.date, container: diary)
        modelContext.delete(ride)
        try? modelContext.save()
        dismiss()
    }
}

private struct WeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var weightKg: Double
    @State private var text: String

    init(weightKg: Binding<Double>) {
        _weightKg = weightKg
        let current = weightKg.wrappedValue
        _text = State(initialValue: current > 0 ? String(format: "%.0f", current) : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("משקל בקילוגרם", text: $text)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("משקל")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ביטול") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("שמור") {
                        let normalized = text.replacingOccurrences(of: ",", with: ".")
                        weightKg = Double(normalized) ?? 0
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
