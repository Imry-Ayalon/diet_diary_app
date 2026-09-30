import Foundation
import SwiftData
import Vision

nonisolated enum FoodRecognizer {
    struct LoggedMeal: Sendable {
        let id: PersistentIdentifier
        let title: String
        let featurePrint: Data?
        let imageData: Data?
    }

    struct Result: Sendable {
        let name: String?
        let featurePrint: Data?
        let printsToSave: [(PersistentIdentifier, Data)]

        static let empty = Result(name: nil, featurePrint: nil, printsToSave: [])
    }

    static func featurePrintData(for imageData: Data) -> Data? {
        guard let image = PhotoImage.cgImage(imageData, maxPixel: photoSide),
              let observation = featurePrint(of: image) else { return nil }
        return archived(observation)
    }

    static func recognize(imageData: Data, meals: [LoggedMeal]) -> Result {
        guard let image = PhotoImage.cgImage(imageData, maxPixel: photoSide) else { return .empty }

        let reading = read(image)
        let remembered = rememberedMeals(from: meals)
        let name = diaryName(matching: reading.featurePrint, in: remembered)
            ?? classifierName(in: reading.classifications)

        return Result(
            name: name,
            featurePrint: reading.featurePrint.flatMap(archived),
            printsToSave: remembered.compactMap(\.printToSave)
        )
    }

    private static let closestMealDistance: Float = 0.55
    private static let minimumGapToNextMeal: Float = 0.05
    private static let minimumClassifierConfidence: VNConfidence = 0.25
    private static let photoSide: CGFloat = 1024

    private struct VisionRead {
        let featurePrint: VNFeaturePrintObservation?
        let classifications: [VNClassificationObservation]
    }

    private struct RememberedMeal {
        let title: String
        let observation: VNFeaturePrintObservation
        let printToSave: (PersistentIdentifier, Data)?
    }

    private static func read(_ image: CGImage) -> VisionRead {
        let featureRequest = VNGenerateImageFeaturePrintRequest()
        let classRequest = VNClassifyImageRequest()
        try? VNImageRequestHandler(cgImage: image, options: [:]).perform([featureRequest, classRequest])
        return VisionRead(
            featurePrint: featureRequest.results?.first,
            classifications: classRequest.results ?? []
        )
    }

    private static func rememberedMeals(from meals: [LoggedMeal]) -> [RememberedMeal] {
        meals.compactMap { meal in
            if let stored = meal.featurePrint, let observation = featurePrint(from: stored) {
                return RememberedMeal(title: meal.title, observation: observation, printToSave: nil)
            }
            guard let imageData = meal.imageData,
                  let image = PhotoImage.cgImage(imageData, maxPixel: photoSide),
                  let observation = featurePrint(of: image) else { return nil }
            let printToSave = archived(observation).map { (meal.id, $0) }
            return RememberedMeal(title: meal.title, observation: observation, printToSave: printToSave)
        }
    }

    private static func diaryName(matching print: VNFeaturePrintObservation?, in meals: [RememberedMeal]) -> String? {
        guard let print else { return nil }

        let distances: [(title: String, distance: Float)] = meals.compactMap { meal in
            let title = meal.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, let distance = distance(from: print, to: meal.observation) else { return nil }
            return (title, distance)
        }

        guard let best = distances.min(by: { $0.distance < $1.distance }),
              best.distance <= closestMealDistance else { return nil }

        let nearestOtherDish = distances
            .filter { $0.title != best.title }
            .min(by: { $0.distance < $1.distance })
        if let nearestOtherDish, best.distance + minimumGapToNextMeal > nearestOtherDish.distance {
            return nil
        }
        return best.title
    }

    private static func classifierName(in classifications: [VNClassificationObservation]) -> String? {
        classifications
            .sorted { $0.confidence > $1.confidence }
            .lazy
            .filter { $0.confidence >= minimumClassifierConfidence }
            .compactMap { hebrewFoodName(for: $0.identifier) }
            .first
    }

    private static func distance(from source: VNFeaturePrintObservation, to other: VNFeaturePrintObservation) -> Float? {
        var distance: Float = 0
        do {
            try source.computeDistance(&distance, to: other)
            return distance
        } catch {
            return nil
        }
    }

    private static func featurePrint(of image: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return request.results?.first
    }

    private static func archived(_ observation: VNFeaturePrintObservation) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
    }

    private static func featurePrint(from data: Data) -> VNFeaturePrintObservation? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
    }

    private static func hebrewFoodName(for identifier: String) -> String? {
        let leaf = identifier.split(separator: "/").last.map(String.init) ?? identifier
        let key = leaf
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: "'", with: "")
        return foodNames[key]
    }

    private static let foodNames: [String: String] = {
        var names: [String: String] = [:]
        func add(_ hebrew: String, _ identifiers: String...) {
            for identifier in identifiers {
                names[identifier] = hebrew
            }
        }

        add("תפוח", "apple", "granny_smith")
        add("בננה", "banana")
        add("תפוז", "orange")
        add("לימון", "lemon")
        add("ליים", "lime")
        add("תות", "strawberry")
        add("ענבים", "grape")
        add("אבטיח", "watermelon")
        add("אננס", "pineapple")
        add("מנגו", "mango")
        add("אפרסק", "peach")
        add("אגס", "pear")
        add("דובדבן", "cherry")
        add("אוכמניות", "blueberry")
        add("פטל", "raspberry")
        add("קיווי", "kiwi")
        add("אבוקדו", "avocado")
        add("תאנה", "fig")
        add("רימון", "pomegranate")
        add("ג'קפרי", "jackfruit")
        add("אנונה", "custard_apple")
        add("עגבנייה", "tomato")
        add("תפוח אדמה", "potato")
        add("פירה", "mashed_potato")
        add("גזר", "carrot")
        add("בצל", "onion")
        add("שום", "garlic")
        add("ברוקולי", "broccoli")
        add("כרובית", "cauliflower")
        add("מלפפון", "cucumber")
        add("חסה", "lettuce")
        add("כרוב", "cabbage", "head_cabbage")
        add("פלפל", "pepper", "bell_pepper")
        add("חציל", "eggplant")
        add("קישוא", "zucchini")
        add("תירס", "corn")
        add("פטריות", "mushroom")
        add("ארטישוק", "artichoke")
        add("דלעת", "acorn_squash", "butternut_squash", "spaghetti_squash")
        add("לחם", "bread", "french_loaf")
        add("בייגל", "bagel")
        add("קרואסון", "croissant")
        add("בייגלה", "pretzel")
        add("פיתה", "pita")
        add("פנקייק", "pancake")
        add("וופל", "waffle")
        add("פרנץ' טוסט", "french_toast")
        add("סופגנייה", "donut", "doughnut")
        add("עוגייה", "cookie")
        add("עוגה", "cake")
        add("קאפקייק", "cupcake")
        add("פאי", "pie", "potpie")
        add("קינוח", "trifle")
        add("שוקולד", "chocolate")
        add("רוטב שוקולד", "chocolate_sauce")
        add("ממתק", "candy")
        add("גלידה", "ice_cream", "icecream")
        add("ארטיק", "ice_lolly")
        add("יוגורט", "yogurt")
        add("גבינה", "cheese")
        add("חמאה", "butter")
        add("ביצה", "egg")
        add("ביצים", "eggs")
        add("חביתה", "omelet", "omelette")
        add("בייקון", "bacon")
        add("נקניק", "sausage")
        add("סטייק", "steak")
        add("בקר", "beef")
        add("חזיר", "pork")
        add("כבש", "lamb")
        add("עוף", "chicken")
        add("הודו", "turkey")
        add("דג", "fish")
        add("סלמון", "salmon")
        add("טונה", "tuna")
        add("שרימפס", "shrimp")
        add("סושי", "sushi")
        add("ראמן", "ramen")
        add("נודלס", "noodle", "noodles")
        add("פסטה", "pasta")
        add("ספגטי", "spaghetti")
        add("קרבונרה", "carbonara")
        add("פיצה", "pizza")
        add("המבורגר", "hamburger", "cheeseburger")
        add("נקניקייה", "hot_dog", "hotdog")
        add("כריך", "sandwich")
        add("טאקו", "taco")
        add("בוריטו", "burrito")
        add("קסדיה", "quesadilla")
        add("נאצ'וס", "nachos")
        add("פלאפל", "falafel")
        add("חומוס", "hummus")
        add("שווארמה", "shawarma")
        add("קבב", "kebab")
        add("סלט", "salad")
        add("גוואקמולי", "guacamole")
        add("מרק", "soup", "consomme")
        add("תבשיל", "stew")
        add("סיר חם", "hot_pot", "hotpot")
        add("אורז", "rice")
        add("אורז מטוגן", "fried_rice")
        add("ריזוטו", "risotto")
        add("קארי", "curry")
        add("כיסונים", "dumpling")
        add("אגרול", "spring_roll")
        add("צ'יפס", "french_fries", "fries")
        add("חטיף תפוחי אדמה", "potato_chips")
        add("פופקורן", "popcorn")
        add("אגוזים", "nuts")
        add("חמאת בוטנים", "peanut_butter")
        add("דבש", "honey")
        add("ריבה", "jam")
        add("דגני בוקר", "cereal")
        add("שיבולת שועל", "oatmeal")
        add("גרנולה", "granola")
        add("בצק", "dough")
        add("קציצות", "meat_loaf", "meatloaf")
        add("קפה", "coffee")
        add("אספרסו", "espresso")
        add("תה", "tea")
        add("מיץ", "juice")
        add("שייק", "smoothie")
        add("חלב", "milk")
        add("משקה ביצים", "eggnog")
        add("יין", "red_wine")
        return names
    }()
}
