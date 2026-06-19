# 📍 GPS Camera App — Flutter

A full-featured Flutter app that captures **photos and videos with GPS location overlays**, displays them on an interactive **OSM map**, and syncs to **Google Drive** and **OneDrive**.

---

## ✨ Features

| Feature | Details |
|---|---|
| 📷 Camera | Photo + Video capture with real-time preview |
| 🗺️ GPS Overlay | Coordinates, address, timestamp watermarked on every capture |
| 🔦 Flash control | Off / Auto / On |
| 🔍 Pinch zoom | Smooth zoom gesture on camera preview |
| 🖼️ Gallery | Grid view with long-press multi-select |
| 🗺️ Map View | Interactive OSM map showing all capture locations |
| ☁️ Google Drive | OAuth sign-in, upload single/all, browse Drive folder |
| ☁️ OneDrive | Microsoft Graph API integration (Azure App required) |
| 📤 Share | Share any photo/video via system share sheet |

---

## 📁 Project Structure

```
lib/
├── main.dart                     # App entry, splash screen
├── models/
│   └── media_item.dart           # MediaItem, LocationData models
├── services/
│   ├── camera_service.dart       # Camera init, capture, GPS watermark
│   ├── location_service.dart     # Geolocator + Geocoding
│   ├── google_drive_service.dart # Google OAuth2 + Drive API
│   ├── onedrive_service.dart     # Microsoft Graph API
│   └── permission_service.dart  # Runtime permissions
└── screens/
    ├── home_screen.dart          # Bottom nav shell
    ├── camera_screen.dart        # Live camera with GPS HUD
    ├── gallery_screen.dart       # Photo/video grid
    ├── map_screen.dart           # Flutter Map (OSM)
    ├── media_detail_screen.dart  # Full preview + upload
    └── cloud_screen.dart         # Drive + OneDrive management
```

---

## 🚀 Quick Start

### 1. Install Flutter
https://flutter.dev/docs/get-started/install

### 2. Clone & install dependencies
```bash
git clone <repo>
cd gps_camera_app
flutter pub get
```

### 3. Set up Google Drive (required for Drive upload)

**a) Create a Google Cloud project**
- Go to https://console.cloud.google.com
- Create a new project
- Enable **Google Drive API** and **Google Sign-In**

**b) Create OAuth credentials**
- OAuth 2.0 → Android (use your package name + SHA-1)
- OAuth 2.0 → Web application (needed for googleapis)

**c) Add `google-services.json`**
- Download from Firebase Console or Cloud Console
- Place at `android/app/google-services.json`

**d) Update `android/app/build.gradle`**
```gradle
apply plugin: 'com.google.gms.google-services'
```

**e) Update `android/build.gradle`**
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
}
```

### 4. Set up OneDrive (required for OneDrive upload)

**a) Register an Azure app**
- Go to https://portal.azure.com → App Registrations → New
- Add redirect URI: `gpscamera://auth` (Mobile and desktop applications)
- Add API permissions: `Files.ReadWrite`, `User.Read`, `offline_access`

**b) Add your Client ID**
```dart
// lib/services/onedrive_service.dart
static const String _clientId = 'YOUR_AZURE_CLIENT_ID';
```

**c) Configure deep link (Android)**
Already in `AndroidManifest.xml`. Handle in `MainActivity.kt`:
```kotlin
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    intent.data?.let { uri ->
        if (uri.scheme == "gpscamera") {
            val code = uri.getQueryParameter("code") ?: return
            // Pass code to Flutter via MethodChannel
        }
    }
}
```

### 5. iOS Permissions

Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera needed to capture GPS photos and videos</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone needed for video recording</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location needed to tag your media with GPS coordinates</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Permission needed to save photos to your gallery</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Permission needed to access your photo library</string>
```

### 6. Run

```bash
flutter run
```

---

## 🗺️ Map Configuration

The app uses **OpenStreetMap** via `flutter_map` — **no API key required**.

To use **Google Maps** instead:
1. Get a Google Maps API key from Cloud Console
2. Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="YOUR_MAPS_API_KEY"/>
```
3. Replace `FlutterMap` with `GoogleMap` widget in `map_screen.dart`

---

## 📦 Key Dependencies

| Package | Purpose |
|---|---|
| `camera` | Camera preview & capture |
| `geolocator` | GPS coordinates |
| `geocoding` | Reverse geocoding (coords → address) |
| `flutter_map` | OSM map (no API key) |
| `google_sign_in` | Google OAuth2 |
| `googleapis` | Google Drive API |
| `image` | GPS watermark rendering |
| `image_gallery_saver` | Save to device gallery |
| `share_plus` | System share sheet |
| `permission_handler` | Runtime permissions |

---

## 📸 GPS Watermark

Every captured photo has a semi-transparent bar stamped with:
- 📍 Latitude / Longitude
- 🏙️ Address (street, city, country)
- 🕐 Date & time
- 📡 GPS accuracy

---

## 🔒 Privacy

- Location data stays on device unless you choose to upload
- Google Drive files go to a dedicated **"GPS Camera"** folder
- OneDrive files go to **"GPS Camera"** folder in root

---

## 🛠️ Troubleshooting

| Issue | Fix |
|---|---|
| Camera not showing | Check camera permission in Settings |
| Location always null | Enable location services; check permission |
| Google Drive sign-in fails | Verify `google-services.json` and SHA-1 fingerprint |
| OneDrive not uploading | Add Azure Client ID and configure deep link |
| Images not saving to gallery | Grant storage/photos permission |
