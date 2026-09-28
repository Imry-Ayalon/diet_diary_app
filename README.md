# Diet diary

A Hebrew iPhone diary for meals and workouts. Photos, names, and reports stay on the phone.

Open `Imry's apps.xcodeproj` in Xcode and run the **Imry's apps** scheme. The project targets iOS 27. The camera works on a device; the simulator can still add meals from the photo library.

## Logging

Each entry has a date, a meal type (or אימון גופני), a name, notes, and an optional photo. The diary groups entries by day.

- Tap a row to edit it.
- Double-tap a row to copy that meal or workout onto today.

After a new meal photo, the form suggests a name. A close match to a meal already logged uses that Hebrew name. Otherwise the on-device image classifier suggests a common food, such as פיצה or סלט. An empty name is filled in. A name you already typed stays as it is, with השתמש if you want the suggestion. The first photo of a homemade dish still needs a typed name; the next similar photo can reuse it.

## Reports

Each day has a daily report inside the app. The toolbar builds a landscape A4 PDF, one page per week, for this week, last week, this month, last month, or a custom range. Share that file with the system share sheet.

## Privacy

Entries are stored with SwiftData on the device. Food recognition uses the Vision framework already on iOS. The app does not download a model and does not send photos anywhere.
