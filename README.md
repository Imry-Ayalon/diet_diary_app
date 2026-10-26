# Diet diary & movement

Two Hebrew-first iPhone apps in one Xcode project. Meals, workouts, routes, and reports stay on the phone. There is no account and no developer server.

| App | Scheme | Bundle ID |
| --- | --- | --- |
| יומן ארוחות (meal diary) | **Meal Diary** | `com.imryayalon.MyApp12345` |
| movement | **Ride** | `com.imryayalon.MyApp12345.ride` |

Shared code lives in `Shared/` (SwiftData diary store, photo helpers, weekly report page model, calendar helpers). The meal diary UI is under `Imry's apps/`. movement is under `Ride/`.

## Install with TestFlight

TestFlight installs do not need Developer Mode. Both apps are set up for an App Store upload: version 1.0 (build 1), no custom encryption, and a privacy manifest.

1. In Xcode, open **Settings > Accounts** and select the Apple ID that is enrolled in the paid Developer Program. The team must be that paid membership, not a free Personal Team.
2. In [App Store Connect](https://appstoreconnect.apple.com/apps), create two iOS apps with those bundle IDs. Names: **יומן ארוחות** and **movement**. SKU can be the bundle ID.
3. In Xcode, choose the **Meal Diary** scheme and **Any iOS Device**, then **Product > Archive**. In the Organizer, **Distribute App > TestFlight & App Store** and upload. Repeat for the **Ride** scheme.
4. When the build finishes processing, open the TestFlight app on the iPhone and install it. Delete the copies that were installed from Xcode first, or iOS may refuse the new install. Deleting them also deletes the meals and rides stored on the phone.

Running from Xcode still needs Developer Mode and a cable. The project targets iOS 27. The camera works on a real device; the simulator can still add meals from the photo library.

App Store copy and review notes live in `AppStore/`. Public privacy and support pages live in `docs/`.

## Meal diary (יומן ארוחות)

Each entry has a date, a meal type (or אימון גופני), a name, notes, and an optional photo. The diary groups entries by day.

- Tap a row to edit it.
- Double-tap a row to copy that meal or workout onto today.

After a new meal photo, the form suggests a name. A close match to a meal already logged uses that Hebrew name. Otherwise the on-device image classifier suggests a common food, such as פיצה or סלט. An empty name is filled in. A name you already typed stays as it is, with השתמש if you want the suggestion. The first photo of a homemade dish still needs a typed name; the next similar photo can reuse it.

### Reports

Each day has a daily report inside the app. The toolbar builds a landscape A4 PDF, one page per week, for this week, last week, this month, last month, or a custom range. Photos in the PDF are optional. Share that file with the system share sheet.

## movement

Choose the **Ride** scheme and run it the same way as the diary. On the phone the app is named **movement**.

### Recording

- Start **רכיבה** (ride), **ריצה** (run), or **הליכה** (walk).
- A short stop pauses by itself and continues when you move. **הפסקה** stays paused until **המשך**. **סיום** saves the route.
- Finished activities are listed by date (newest first). Swipe or open an activity to delete it.
- If the meal diary is installed on the same phone (shared App Group), finish also adds an אימון גופני row: רכיבת אופניים, ריצה, or הליכה.
- Enter weight from the menu if you want an on-device calorie estimate. Location is used only while an activity is in progress and stays on the phone. Map pictures may still load from Apple when sharing with a map background.

### Menu (hamburger)

Top-corner menu includes:

- **Weight** — used only for calorie estimates on device
- **Weekly report** — landscape A4 PDF of rides / runs / walks by day for a chosen range
- **Language** — Hebrew (RTL) or English (LTR)
- **Instructions**, **FAQ**, and **Privacy** — in-app documents

### Sharing an activity

From a saved activity, share either:

- an image with the **map** route as the background, or
- an image with a **photo** from the library as the background

Stats (distance, time, ascent, speed) are drawn on top. The file leaves the phone only through the system share sheet.

## Privacy

Entries and routes are stored with SwiftData on the device (App Group container when both apps are installed). Food recognition uses the Vision framework already on iOS. The apps do not download a model and do not send photos, meals, or routes to the developer. Sharing is optional and goes to the app the user picks on Apple’s share sheet.

See `docs/privacy.html` for the full policy (Hebrew and English).
