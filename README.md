# Diet diary

A Hebrew iPhone diary for meals and workouts. Photos, names, and reports stay on the phone.

## Install with TestFlight

TestFlight installs do not need Developer Mode. Both apps are set up for an App Store upload: version 1.0 (build 1), no custom encryption, and a privacy manifest. The bundle IDs are `com.imryayalon.MyApp12345` (יומן ארוחות) and `com.imryayalon.MyApp12345.ride` (movement).

1. In Xcode, open **Settings > Accounts** and select the Apple ID that is enrolled in the paid Developer Program. The team must be that paid membership, not a free Personal Team.
2. In [App Store Connect](https://appstoreconnect.apple.com/apps), create two iOS apps with those bundle IDs. Names: **יומן ארוחות** and **movement**. SKU can be the bundle ID.
3. In Xcode, choose the **Meal Diary** scheme and **Any iOS Device**, then **Product > Archive**. In the Organizer, **Distribute App > TestFlight & App Store** and upload. Repeat for the **Ride** scheme.
4. When the build finishes processing, open the TestFlight app on the iPhone and install it. Delete the copies that were installed from Xcode first, or iOS may refuse the new install. Deleting them also deletes the meals and rides stored on the phone.

Running from Xcode still needs Developer Mode and a cable. The project targets iOS 27. The camera works on a real device; the simulator can still add meals from the photo library.

## movement

The same Xcode project also builds **movement**. Choose the **Ride** scheme, then run it on your iPhone the same way as the diary. On the phone the app is named movement. Tap **רכיבה** or **ריצה**. A stop pauses by itself and continues when you move. **הפסקה** stays paused until **המשך**. **סיום** saves the route and adds an אימון גופני row: רכיבת אופניים or ריצה. Enter your weight once if you want a calorie estimate. Location is used only while an activity is in progress and stays on the phone. Map pictures may still load from Apple. The first time Xcode signs it, allow the App Group so the finished activity can be added to the diary’s sport section.

## Logging

Each entry has a date, a meal type (or אימון גופני), a name, notes, and an optional photo. The diary groups entries by day.

- Tap a row to edit it.
- Double-tap a row to copy that meal or workout onto today.

After a new meal photo, the form suggests a name. A close match to a meal already logged uses that Hebrew name. Otherwise the on-device image classifier suggests a common food, such as פיצה or סלט. An empty name is filled in. A name you already typed stays as it is, with השתמש if you want the suggestion. The first photo of a homemade dish still needs a typed name; the next similar photo can reuse it.

## Reports

Each day has a daily report inside the app. The toolbar builds a landscape A4 PDF, one page per week, for this week, last week, this month, last month, or a custom range. Share that file with the system share sheet.

## Privacy

Entries are stored with SwiftData on the device. Food recognition uses the Vision framework already on iOS. The app does not download a model and does not send photos anywhere.
