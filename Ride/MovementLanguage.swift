import SwiftUI

enum MovementLanguage: String, CaseIterable, Identifiable {
    case hebrew = "he"
    case english = "en"

    var id: String { rawValue }

    var layoutDirection: LayoutDirection {
        self == .hebrew ? .rightToLeft : .leftToRight
    }

    var locale: Locale {
        Locale(identifier: self == .hebrew ? "he_IL" : "en_US")
    }

    var menuLabel: String {
        switch self {
        case .hebrew: "עברית"
        case .english: "English"
        }
    }
}

private struct MovementLanguageKey: EnvironmentKey {
    static let defaultValue: MovementLanguage = .hebrew
}

extension EnvironmentValues {
    var movementLanguage: MovementLanguage {
        get { self[MovementLanguageKey.self] }
        set { self[MovementLanguageKey.self] = newValue }
    }
}

enum MovementText {
    static func t(_ hebrew: String, _ english: String, _ language: MovementLanguage) -> String {
        language == .english ? english : hebrew
    }

    static func dayNames(_ language: MovementLanguage) -> [String] {
        language == .english
            ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            : ["ראשון", "שני", "שלישי", "רביעי", "חמישי", "שישי", "שבת"]
    }

    static func privacy(_ language: MovementLanguage) -> String {
        t(
            """
            מדיניות פרטיות — movement

            עודכן ב-26 באוקטובר 2026.
            המפתח: Imry Ayalon, imry.ayalon@icloud.com.
            אין שרת של המפתח, ולמפתח אין גישה למידע באפליקציה.

            המידע נשאר בטלפון
            מסלולים, מרחקים, זמנים, עלייה, משקל ואומדן קלוריות נשמרים בזיכרון המכשיר בלבד. מחיקת האפליקציה מוחקת אותם. אי אפשר לשחזר אותם דרך המפתח.

            אם גם יומן ארוחות מותקן באותו טלפון, סיום פעילות יכול להוסיף שורת אימון ליומן. גם זה נשאר באותו מכשיר.

            מתי מידע יוצא מהמכשיר
            רק אם לוחצים על שיתוף: תמונת מסלול או תמונה שבחרתם, או דוח PDF שבועי. הקובץ עובר לאפליקציה שנבחרת במסך השיתוף של אפל, לא למפתח.

            כדי לצייר מפה, האפליקציה מבקשת מאפל תמונת מפה של האזור. הבקשה הולכת לאפל, לא למפתח.

            מה אין כאן
            אין חשבון, אין פרסומות, אין מעקב ואין אנליטיקה.

            ילדים
            האפליקציה לא מיועדת לילדים מתחת לגיל 13.
            """,
            """
            Privacy policy — movement

            Updated 26 October 2026.
            Developer: Imry Ayalon, imry.ayalon@icloud.com.
            There is no developer server, and the developer has no access to information in the app.

            Information stays on the iPhone
            Routes, distances, times, ascent, weight, and calorie estimates are stored only in the device’s memory. Deleting the app deletes them. The developer cannot restore them.

            If the meal diary is also installed on the same iPhone, finishing an activity can add a workout row to the diary. That row stays on the same device.

            When information leaves the device
            Only if you tap share: a route image, a photo you chose, or a weekly PDF report. The file goes to the app you pick on Apple’s share sheet, not to the developer.

            To draw a map, the app asks Apple for a map image of that area. That request goes to Apple, not to the developer.

            What this app does not do
            There is no account, no advertising, no tracking, and no analytics.

            Children
            The app is not directed at children under 13.
            """,
            language
        )
    }

    static func instructions(_ language: MovementLanguage) -> String {
        t(
            """
            הוראות שימוש

            1. הזינו משקל בתפריט אם תרצו אומדן קלוריות.
            2. בחרו רכיבה, ריצה או הליכה כדי להתחיל הקלטה.
            3. אשרו מיקום כשהמערכת מבקשת — בלי מיקום אין מדידה.
            4. עצירה קצרה (למשל רמזור) עוצרת את הזמן לבד. אפשר גם להפסיק ידנית.
            5. בסיום לוחצים סיום. הפעילות נשמרת ברשימה, ואם יומן הארוחות מותקן — גם שם.
            6. בפעילות שמורה אפשר לשתף תמונה עם מפת מסלול, או עם תמונה מהגלריה.
            7. בתפריט אפשר לייצא דוח שבועי כ־PDF, להחליף שפה, ולקרוא פרטיות, הוראות ושאלות נפוצות.
            """,
            """
            Instructions

            1. Enter your weight in the menu if you want a calorie estimate.
            2. Choose Ride, Run, or Walk to start recording.
            3. Allow location when asked — without it there is no measurement.
            4. A short stop (for example at a light) pauses time automatically. You can also pause by hand.
            5. Tap Finish when done. The activity is saved in the list, and in the meal diary if that app is installed.
            6. On a saved activity you can share an image with the route map, or with a photo from your library.
            7. In the menu you can export a weekly PDF report, switch language, and read privacy, instructions, and FAQ.
            """,
            language
        )
    }

    static func faq(_ language: MovementLanguage) -> String {
        t(
            """
            שאלות נפוצות

            למה צריך מיקום?
            כדי למדוד מרחק, מסלול, מהירות ועלייה. המיקום נשמר במכשיר ולא נשלח למפתח.

            למה ההקלטה נעצרה לבד?
            עצירה איטית קצרה נחשבת להפסקת תנועה (למשל רמזור). כשחוזרים לנוע — ההקלטה ממשיכה.

            איך מוחקים פעילות?
            מחליקים ברשימה או נכנסים לפעילות ולוחצים מחק. אם יש יומן ארוחות, שורת האימון המקושרת מוסרת גם משם.

            מה אומדן הקלוריות?
            חישוב משוער לפי משקל, מרחק וזמן. זה לא ייעוץ רפואי.

            האם אפשר לשתף בלי מפה?
            כן. בשיתוף אפשר לבחור תמונה מהגלריה במקום רקע המפה.

            איפה הדוח השבועי?
            בתפריט ההמבורגר → דוח שבועי. בוחרים טווח תאריכים ומשתפים PDF.
            """,
            """
            FAQ

            Why does the app need location?
            To measure distance, route, speed, and ascent. Location stays on the device and is not sent to the developer.

            Why did recording pause by itself?
            A short slow stop counts as a traffic pause. Moving again resumes recording.

            How do I delete an activity?
            Swipe in the list, or open the activity and tap Delete. If the meal diary is installed, the linked workout row is removed there too.

            What is the calorie figure?
            An estimate from weight, distance, and time. It is not medical advice.

            Can I share without the map?
            Yes. When sharing you can choose a photo from your library instead of the map background.

            Where is the weekly report?
            Open the hamburger menu → Weekly report. Pick a date range and share a PDF.
            """,
            language
        )
    }
}
