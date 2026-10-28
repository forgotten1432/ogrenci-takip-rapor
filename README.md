# Öğrenci Takip Raporu

A standalone Flutter web app for the teacher dashboard and weekly/monthly lesson reports. It has no Firebase or server connection. Student and lesson records are saved in the current browser's local storage, separately for each class and device.

The public site contains only the app code. It does not store or sync student records. Clearing browser data removes local records, so use **Backup** in the app to copy a JSON backup and restore it on another browser or device.

## GitHub Pages

The workflow builds and publishes on each push to `main`:

https://forgotten1432.github.io/ogrenci-takip-rapor/

## Run locally

```sh
flutter pub get
flutter run -d chrome
```
