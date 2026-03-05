# Alur Hymn App - Deployment Instructions

This document provides instructions on how to build, test, and deploy the Alur Hymn App to the Google Play Store.

## 1. Running Locally
- Ensure you have the [Flutter SDK installed](https://docs.flutter.dev/get-started/install).
- Connect an Android device or start an emulator.
- Install dependencies: `flutter pub get`
- If you made changes to Hive models, run: `dart run build_runner build -d`
- Run the app: `flutter run`

## 2. Supabase Configuration
- Supabase connects natively. It expects the anon_key.
- To use your own Supabase instance, update `lib/main.dart` with your actual URL and Anon Key.
- Make sure you enabled RLS or permissive settings on the `hymns` table so the app can fetch data without logging in. Since users only download hymns and the app does not allow uploads, a simple read policy is enough.

## 3. Sharing with Your Team (Testing)

The easiest way to share the app with your team before releasing it to the public is by generating an **APK** file. This is a standalone installer file that Android devices can run directly.

1.  **Generate the APK (I have just done this for you):**
    Open your terminal and run:
    ```bash
    flutter build apk --release
    ```
2.  **Locate the File:**
    Once complete, you can find the shareable file here:
    `/home/sam/Documents/projects/alurHymns/build/app/outputs/flutter-apk/app-release.apk`
3.  **Share:**
    Simply send this `app-release.apk` file to your team members (e.g., via WhatsApp, Email, Google Drive, Telegram). They can tap it on their Android phones to install the "Alur Hymns" app and start testing immediately!

***

## 4. Google Play Store Deployment

When the app has been reviewed by your team and is ready for the public, you need to publish it on the Google Play Store. The Play Store requires an **AAB** (Android App Bundle) file, which is much more optimized than an APK.

### Step-by-Step Play Store Prep

**1. Create a Google Play Developer Account**
Ensure you or your organization has registered for a [Google Play Developer account](https://play.google.com/console/signup) (there is a one-time $25 fee).

**2. Update the Version Number (If releasing an update)**
Whenever you publish an update to the Play Store, you must increment the version number in your `pubspec.yaml` file:
```yaml
version: 1.0.0+1
```
*   `1.0.0` is the version name users see (e.g., change to `1.0.1` for small fixes).
*   `+1` is the build code (this MUST go up by at least 1 every single time you upload to the Play Console, e.g., `+2`).

**3. Generate the App Bundle (AAB)**
Open your terminal and run the following command to package the app for submission:
```bash
flutter build appbundle --release
```

**4. Locate your Submission File**
Once the build completes, your upload file will be located at:
`/home/sam/Documents/projects/alurHymns/build/app/outputs/bundle/release/app-release.aab`

**5. Upload to Google Play Console**
1.  Go to your Play Console Dashboard.
2.  Create a "New App", fill in the titles and descriptions ("Alur Hymns").
3.  Upload your app icon (`assets/final_icon.png` is what we used) and screenshots.
4.  Navigate to **Testing > Closed testing** or **Production**.
5.  Create a new Release.
6.  Upload the `app-release.aab` file you created in Step 4.
7.  Fill out the release notes, save, and send it to Google for review!
