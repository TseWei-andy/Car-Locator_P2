# Car Locator Setup Instructions

Since the Flutter environment was not detected in the current session, I have created the core application code for you. Please follow these steps to get the app running.

## 1. Ensure Flutter is Installed
Make sure you have Flutter installed and added to your PATH. You can verify this by running:
```bash
flutter doctor
```

## 2. Initialize the Project Structure
Open a terminal in this folder (`Car Locator`) and run:
```bash
flutter create .
```
This will generate the necessary Android and iOS project files. If it asks to overwrite `lib/main.dart` or `pubspec.yaml`, choose **NO** (or back up my files first), but typically it respects existing files or you can restore them from the code I provided.
*Recommendation: If `flutter create .` overwrites the files, simply copy the code from `lib/main.dart` provided below back into the file.*

## 3. Install Dependencies
Run the following command to install the required packages:
```bash
flutter pub get
```

## 4. Configure Permissions (Crucial!)

### Android
Open `android/app/src/main/AndroidManifest.xml` and add the following lines just before the `<application>` tag:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS
Open `ios/Runner/Info.plist` and add the following keys inside the `<dict>` tag:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to save your parking spot.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location to save your parking spot.</string>
```

## 5. Run the App
Connect your device or start an emulator, then run:
```bash
flutter run
```

## Core Code (for reference)
The logic is implemented in `lib/main.dart`. It uses:
- `geolocator` for getting GPS coordinates.
- `shared_preferences` for saving the data locally.
- `url_launcher` for opening Google Maps navigation.
