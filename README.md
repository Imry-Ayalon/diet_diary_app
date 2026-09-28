# Diet diary

A Hebrew iPhone diary for meals and workouts. Photos, names, and reports stay on the phone.

## How to run on your iPhone

To install this app on your own iPhone, you will need a Mac with Xcode installed.

1. **Download the code:** Clone this repository or download the ZIP file.
2. **Open the project:** Double-click `Imry's apps.xcodeproj` to open it in Xcode.
3. **Connect your iPhone:** Plug your iPhone into your Mac using a cable.
4. **Trust your Mac:** If prompted on your iPhone, tap "Trust This Computer".
5. **Enable Developer Mode:** On your iPhone, go to **Settings > Privacy & Security > Developer Mode** and turn it on. Your iPhone will restart. After it restarts, unlock it and confirm you want to turn on Developer Mode.
6. **Set up signing in Xcode:** 
   - In Xcode, click on `Imry's apps` at the very top of the left sidebar (the Project Navigator).
   - Go to the **Signing & Capabilities** tab.
   - Check "Automatically manage signing".
   - Select your personal Apple ID from the **Team** dropdown (you may need to sign in with your Apple ID in Xcode Settings first).
7. **Install:** At the top of the Xcode window, select your iPhone from the device list next to the Play button, then click the **Play** button (or press `Cmd+R`) to build and install the app.
8. **Trust the developer:** The first time you try to open the app on your phone, it might say "Untrusted Developer". Go to **Settings > General > VPN & Device Management**, tap your Apple ID under "Developer App", and choose to trust it.

*(Note: The project targets iOS 27. The camera works on a real device; the simulator can still add meals from the photo library).*

## Logging

Each entry has a date, a meal type (or אימון גופני), a name, notes, and an optional photo. The diary groups entries by day.

- Tap a row to edit it.
- Double-tap a row to copy that meal or workout onto today.

After a new meal photo, the form suggests a name. A close match to a meal already logged uses that Hebrew name. Otherwise the on-device image classifier suggests a common food, such as פיצה or סלט. An empty name is filled in. A name you already typed stays as it is, with השתמש if you want the suggestion. The first photo of a homemade dish still needs a typed name; the next similar photo can reuse it.

## Reports

Each day has a daily report inside the app. The toolbar builds a landscape A4 PDF, one page per week, for this week, last week, this month, last month, or a custom range. Share that file with the system share sheet.

## Privacy

Entries are stored with SwiftData on the device. Food recognition uses the Vision framework already on iOS. The app does not download a model and does not send photos anywhere.
