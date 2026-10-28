# Öğrenci Takip Raporu

A standalone Flutter web app for the teacher dashboard and weekly/monthly lesson reports. It has no Firebase or server connection. Student and lesson records stay in this device’s browser storage, separately for each class. The app requests persistent storage where the browser supports it and includes a JSON download/restore backup.

The public site contains only the app code. It does not store or sync student records. Persistent storage reduces automatic eviction, but clearing site data or uninstalling the browser can still remove records. Download the JSON backup from the app to keep a copy in Files/Downloads.

## GitHub Pages

The workflow builds and publishes on each push to `main`:

https://forgotten1432.github.io/ogrenci-takip-rapor/

## Run locally

```sh
flutter pub get
flutter run -d chrome
```
