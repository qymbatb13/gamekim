# Noir Blocks (Flutter)

1. Install Flutter (https://docs.flutter.dev/get-started/install), version 3.27 or newer.
2. Copy your photos into `assets/photos/`.
3. In this folder run:
   flutter create .          (generates the android/ios folders, keeps lib/ and pubspec.yaml)
   flutter pub get
4. Phone connected with USB debugging:  flutter run --release
   Or build an APK to send to a phone:  flutter build apk --release
   The file appears at build/app/outputs/flutter-apk/app-release.apk
