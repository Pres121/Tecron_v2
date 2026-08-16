# Tecron — Flutter Frontend

Dart/Flutter UI with Firebase Authentication + Firestore, talking to a FastAPI backend
for predictions.

## Folder structure

```
frontend/
├── pubspec.yaml
├── lib/
│   ├── main.dart                          # Firebase init + app entry point
│   ├── firebase_options.dart              # PLACEHOLDER -- replace via `flutterfire configure`
│   ├── config/
│   │   └── api_config.dart                # backend base URL (currently localhost)
│   ├── models/
│   │   ├── phone_spec.dart                # prediction request body
│   │   ├── prediction_result.dart         # prediction response + ApiException
│   │   └── prediction_history_entry.dart  # Firestore history document model
│   ├── services/
│   │   ├── prediction_api_service.dart    # REST client for the FastAPI backend
│   │   ├── auth_service.dart              # Firebase Auth wrapper
│   │   └── firestore_service.dart         # Firestore read/write for history
│   ├── theme/
│   │   └── app_theme.dart                 # white/green Tecron theme
│   ├── widgets/
│   │   ├── phone_form.dart
│   │   ├── wattage_gauge.dart
│   │   └── source_badge.dart
│   └── screens/
│       ├── splash_screen.dart             # animated intro -> AuthGate
│       ├── auth_gate.dart                 # routes to LoginScreen or HomeScreen
│       ├── login_screen.dart
│       ├── signup_screen.dart
│       ├── home_screen.dart               # prediction form + result
│       └── history_screen.dart            # past predictions from Firestore
└── README.md
```

## 1. Set up Firebase (required before this runs)

The project won't compile-and-connect correctly until you do this — `firebase_options.dart`
is currently a placeholder with fake keys.

```bash
npm install -g firebase-tools      # if you don't have the Firebase CLI
firebase login
dart pub global activate flutterfire_cli
cd frontend
flutterfire configure
```

`flutterfire configure` will:
- prompt you to pick (or create) a Firebase project
- ask which platforms to register (select at least **web**, plus android/ios if/when you add them)
- **overwrite `lib/firebase_options.dart`** with real values automatically

Then in the Firebase console for that project:
1. **Authentication -> Sign-in method** -> enable **Email/Password**
2. **Firestore Database** -> create a database (start in test mode for local dev, then
   lock it down — see the security rule below before shipping)

### Recommended Firestore security rule

Each user's prediction history lives at `users/{uid}/predictions/{docId}`. In the
Firestore console under **Rules**:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/predictions/{predictionId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

This ensures a signed-in user can only ever read or write their own history.

## 2. Point the app at your backend

`lib/config/api_config.dart` currently defaults to `http://localhost:8000`, matching
`flutter run -d chrome` against a locally running FastAPI instance. See the comments in
that file for the Android-emulator/physical-device variants. When the backend is
deployed to Render, this is the one line to change (see the backend README).

## 3. Run it

```bash
flutter pub get
flutter run -d chrome
```

Make sure the FastAPI backend is running locally first (see `backend/README.md`) —
otherwise sign-up/login will work (that's all Firebase), but predictions will fail with
a connection error.

## What's wired up vs. what's a placeholder

| Piece | Status |
|---|---|
| Email/password sign up, login, sign out, password reset | Fully wired to Firebase Auth |
| Auth-gated navigation (splash -> login/signup -> home) | Fully wired |
| Prediction history saved to Firestore on every successful prediction | Fully wired |
| History screen (list, delete) | Fully wired |
| Prediction calls to FastAPI backend | Fully wired, pointed at localhost for now |
| `firebase_options.dart` | **Placeholder — you must run `flutterfire configure`** |
| Google/Apple/etc. social sign-in | Not implemented (email/password only) |
| Offline support / caching | Not implemented — Firestore's default online behavior |
