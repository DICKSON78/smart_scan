# Exam Mark Extractor

A Flutter application that automatically extracts student registration numbers and marks from exam papers using OCR technology and generates Excel reports.

## Features

- **Image Capture**: Take pictures of exam papers using camera or select from gallery
- **Bulk Processing**: Process multiple exam papers at once
- **OCR Extraction**: Automatically extract registration numbers and marks using Google ML Kit
- **Excel Generation**: Generate Excel files with extracted marks
- **Authentication**: Sign up and sign in with Firebase Auth
- **Onboarding**: Three-screen onboarding flow for new users
- **History**: View past extraction history
- **Settings**: Manage app settings and account
- **Purchase Packages**: Subscription plans for premium features

## Screens

1. **Onboarding Screens** (3 screens)
   - Extract Exam Marks
   - Generate Excel Reports
   - Bulk Processing

2. **Authentication Screens**
   - Sign Up
   - Sign In

3. **Main Screens**
   - Home (Image capture and extraction)
   - History (Past extractions)
   - Settings (App configuration)
   - Purchase Package (Subscription plans)

## Prerequisites

- Flutter SDK (3.10.4 or higher)
- Dart SDK
- Android Studio / Xcode
- Firebase account (for authentication)

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Firebase Configuration

1. Create a Firebase project at [https://console.firebase.google.com/](https://console.firebase.google.com/)
2. Add Android app:
   - Download `google-services.json` and place it in `android/app/`
3. Add iOS app:
   - Download `GoogleService-Info.plist` and place it in `ios/Runner/`
4. Enable Authentication (Email/Password) in Firebase Console

### 3. Android Setup

The following permissions are already configured in `android/app/src/main/AndroidManifest.xml`:
- INTERNET
- CAMERA
- READ_EXTERNAL_STORAGE
- WRITE_EXTERNAL_STORAGE
- READ_MEDIA_IMAGES

### 4. iOS Setup

The following permissions are already configured in `ios/Runner/Info.plist`:
- NSCameraUsageDescription
- NSPhotoLibraryUsageDescription
- NSPhotoLibraryAddUsageDescription

### 5. Run the App

```bash
# For Android
flutter run

# For iOS
flutter run -d ios

# For web (limited support)
flutter run -d chrome
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── student_mark.dart     # Data model for extracted marks
├── providers/
│   ├── auth_provider.dart    # Authentication state management
│   └── onboarding_provider.dart # Onboarding state management
├── routes/
│   └── app_router.dart       # Navigation configuration
├── screens/
│   ├── auth/
│   │   ├── sign_in_screen.dart
│   │   └── sign_up_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── history/
│   │   └── history_screen.dart
│   ├── onboarding/
│   │   └── onboarding_screen.dart
│   ├── purchase/
│   │   └── purchase_package_screen.dart
│   └── settings/
│       └── settings_screen.dart
└── services/
    ├── excel_service.dart    # Excel generation
    └── ocr_service.dart      # OCR text extraction
```

## Key Dependencies

- `provider` - State management
- `go_router` - Navigation
- `image_picker` - Image selection
- `camera` - Camera access
- `google_ml_kit` - OCR text recognition
- `excel` - Excel file generation
- `firebase_auth` - Authentication
- `shared_preferences` - Local storage

## Usage

1. **First Launch**: Complete the onboarding screens
2. **Sign Up**: Create an account with email and password
3. **Extract Marks**:
   - Tap "Camera" to take a photo or "Gallery" to select images
   - Select multiple images for bulk processing
   - Tap "Extract Marks" to process images
4. **View Results**: Switch to the "Results" tab to see extracted marks
5. **Export Excel**: Tap "Export Excel" to generate and share the Excel file
6. **History**: View past extractions in the History screen
7. **Settings**: Manage your account and app preferences

## OCR Pattern Configuration

The OCR service uses regex patterns to extract registration numbers and marks. You may need to adjust these patterns in `lib/services/ocr_service.dart` based on your exam format:

- Registration number pattern: `[A-Z]{0,3}\d{4,10}`
- Mark pattern: `\b\d{1,3}\b` (validates marks 0-100)

## Future Enhancements

- Cloud storage for history
- Custom OCR pattern configuration
- Payment integration for subscriptions
- Multi-language support
- Dark mode implementation
- Export to CSV/PDF formats

## Troubleshooting

### Camera not working
- Ensure camera permissions are granted
- Check if the device has a camera
- For iOS, ensure camera is added to Info.plist

### OCR not extracting marks
- Ensure images are clear and well-lit
- Check if registration numbers and marks are visible
- Adjust regex patterns in `ocr_service.dart`

### Firebase authentication issues
- Verify Firebase configuration files are in place
- Check if Email/Password authentication is enabled in Firebase Console
- Ensure internet connection is available

## License

This project is created for educational purposes.
