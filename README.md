# 🌱 GrowLens — AI-Powered Gardening Assistant

GrowLens is a cross-platform Flutter application that helps home gardeners identify plant diseases and pests, plan garden layouts with AI, track weather conditions, and manage day-to-day plant care. It was built as a Final Year Project, combining a Flutter front end with Firebase services and custom machine-learning backends for image-based plant analysis.

## ✨ Features

### 🔍 Plant Health Scanning
- **Disease Detection** — Upload or capture leaf images to get an AI-generated diagnosis and care report (backed by a custom ML API and Gemini-generated explanations).
- **Pest Detection** — Identify common garden pests from photos and get treatment suggestions.
- **Scan History** — Every disease/pest scan is saved to Firestore per user, so past results can be revisited anytime.

### 🌿 Garden Design
- Upload a photo of your garden space and generate AI-assisted garden design suggestions based on your preferences.
- Design history is stored per user for future reference.

### 🌦️ Weather & Location
- Live current weather and multi-day forecast via WeatherAPI.
- Automatic location detection (with graceful fallback to a default city) using `geolocator` and `geocoding`.

### 📅 Care Schedule
- Track recurring plant care tasks (watering, fertilizing, pruning, pest inspections) with local reminders.

### 👤 Accounts & Profile
- Email/password authentication (sign up, login, forgot password) via Firebase Auth.
- User profile management with Firestore-backed data.

### 🛠️ Admin Panel
- Role-based user management (activate/deactivate users, assign roles).
- Model performance monitoring — aggregated confidence stats across disease/pest predictions.
- Visibility into pending model retraining jobs.

## 🧱 Tech Stack

| Layer | Technology |
|---|---|
| Client | Flutter (Dart), Material Design |
| Auth & Data | Firebase Auth, Cloud Firestore, Firebase Storage |
| Disease/Pest ML | Custom FastAPI backend + Gemini API for report generation |
| Garden Design ML | Custom FastAPI backend (`/design-garden/` endpoint) |
| Weather | WeatherAPI.com |
| Location | `geolocator`, `geocoding` |
| Local Storage | `shared_preferences` |

## 📂 Project Structure

```
lib/
├── main.dart                     # App entry point & Firebase init
├── firebase_options.dart         # Generated Firebase config
├── screens/                      # All app screens (auth, home, scan, garden, schedule, admin, etc.)
├── services/                     # API/business logic (auth, weather, disease/pest API, garden design, admin, etc.)
├── widgets/                      # Reusable UI components
└── utils/                        # Theming and color constants
```

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart >=3.0.0)
- A Firebase project with Auth, Firestore, and Storage enabled
- Access to the disease/pest and garden-design ML backend services (or your own compatible deployment)

### Setup

1. **Clone and install dependencies**
   ```bash
   flutter pub get
   ```

2. **Firebase configuration**
   This project uses `firebase_options.dart` generated via the FlutterFire CLI. If setting up a new Firebase project:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

3. **Backend endpoints (optional overrides)**
   The Garden Design service auto-detects a backend from a list of candidate URLs, but you can override it at run time:
   ```bash
   flutter run --dart-define=GARDEN_API_BASE_URL=http://<your-ip>:8000
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Supported Platforms
Android, iOS, Web, Windows, macOS, and Linux project scaffolding are all included, though the app is primarily designed and tested for mobile (Android/iOS).

## ⚠️ Notes

- API keys for the disease-detection and weather services are currently embedded in source (`lib/services/disease_api_service.dart`, `lib/services/weather_service.dart`). For any production deployment, move these to secure environment configuration before publishing.
- Firestore security rules (`firestore.rules`) restrict all user data (profile, plants, scan history, garden designs) to the owning authenticated user.

## 📖 About

GrowLens was developed as a Final Year Project to explore how mobile apps and machine learning can make plant care more accessible to home gardeners — from diagnosing sick plants to planning a new garden layout.

## Demo

Watch a complete walkthrough of the platform:

🎥 **Youtube Demo:** https://www.youtube.com/watch?v=l6P9Nj5Tmgs
