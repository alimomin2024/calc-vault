# CalcVault: Secret Calculator & Photo Locker

Native Android/iOS Flutter app built from the AdCraft AI design reference: warm linen, charcoal cards, khaki highlights, Playfair Display and Plus Jakarta Sans. Fonts and decoy samples are bundled. The launcher label and icon say Calculator.

## Run

```sh
cd /Users/alimomin/studioprojects/calc_vault
flutter pub get
flutter run
```

Set a master PIN and a different secondary PIN on the first launch. There are no built-in production PINs. Enter either PIN in the calculator and press `=`. The secondary PIN opens its own isolated store, seeded with two harmless local landscape illustrations. It never loads the primary media manifest.

## Features

- Working arithmetic, parentheses, powers, square roots, percentages, trigonometry, logarithms, degree/radian modes and session-only calculator history. PIN-length entries are excluded from history. Percent is a postfix divide-by-100 operator; `200 × 10%` is `20`.
- Authenticated AES-256-GCM encryption of media, records, filenames and folders. Every encrypted object uses a fresh 96-bit random nonce and a 128-bit authentication tag. Associated data binds files to their object/domain.
- Random 256-bit keys wrapped by a salted, 120,000-iteration PBKDF2-HMAC-SHA256 PIN-derived key. Credentials and wrapped keys reside in Android Keystore-backed storage/iOS device-only Keychain. No plaintext vault keys remain in the retained configuration.
- Gallery import of local photos/videos, verified encrypted copy before optional original deletion, folders, search, full-screen photo pinch zoom, video and audio playback, audio recording, password/card records, permanent deletion and folder moves.
- Separate decoy storage and encryption key. Persistent failed-attempt counter; three failures start a 30-second cooldown, increasing with further failed attempts.
- Opt-in front-camera evidence after every third new failed PIN attempt, encrypted in a separate evidence store. Optional panic flip locks after ~200 ms face-down; backgrounding always locks and removes private routes.
- Android FLAG_SECURE blocks app screenshots/recording and app-switcher snapshots. Native iOS privacy cover obscures inactive app snapshots; iOS screenshots of an active vault cannot be universally prevented.
- Android debug builds include the standard `INTERNET` permission so Flutter can connect its VM service to localhost for hot reload. The release APK removes `INTERNET` and `ACCESS_NETWORK_STATE`. No app networking, telemetry, sign-in, ads, cloud sync, or runtime font downloads. OS backups and device-transfer of app data are disabled/excluded. Vendored `photo_manager` disables all PhotoKit network access, including thumbnails. Cloud-only media cannot be imported.

## Security and platform limits

Short PINs have low entropy; choose a long unique PIN. Device secure storage and throttling reduce exposure, but there is no guarantee on rooted/jailbroken or compromised devices. Dart cannot promise perfect memory zeroization or forensic secure erasure. Do not use this development build as a substitute for an independent security audit.

Camera evidence requires prior opt-in permission. Android/iOS can show privacy indicators or system permission UI, so truly invisible capture cannot be guaranteed. Missing/denied camera or accelerometer hardware degrades gracefully. Hardware capture, permissions, original-deletion confirmation and panic-flip behavior need acceptance testing on physical devices.

Photos are decrypted in memory. Audio/video playback and in-progress recordings use private plaintext temporary files; these are removed on viewer close, lock and launch. Imported PhotoKit caches are also cleared. OS process termination may leave a cache until the next launch. Imports are limited to 150 MB per file and encrypt in memory; large media consumes RAM. Supported preview codecs depend on the device.

Import is non-destructive unless the user explicitly confirms deleting originals. OS deletion may leave originals in Recently Deleted or copies in the system photo library's own backups; CalcVault does not control those services. Card records do not provide autofill/payment features. Uninstalling, forgetting your PIN or losing the device can permanently lose vault access; no reset, export, cloud backup or recovery is implemented. iOS Keychain may survive uninstall, but encrypted app files do not.

Release builds currently use Flutter's development signing configuration on Android. Configure a production signing key before distribution. The debug-only `INTERNET` permission exists for Flutter’s localhost VM service; release builds omit it.

## Validation

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --no-pub
flutter build ios --simulator --no-pub
```

Tests cover calculator precedence and malformed input; AES-GCM round trips, wrong keys, wrong associated data and ciphertext tampering; real/decoy isolation and encrypted manifests; cooldown persistence; locking and damaged-manifest failure; folder changes/deletion; compact layouts; PIN-equals unlock and background route removal.

`tool/render_previews.dart` produces screenshots with sample data using the Flutter test renderer; it never inserts samples into the production primary vault.

`packages/photo_manager` is version 3.12.0, vendored under its upstream license. The local change replaces every PhotoKit `networkAccessAllowed = YES`/`setNetworkAccessAllowed:YES` with `NO`. Preserve this patch when updating the plugin. Package guidance: https://pub.dev/packages/encrypt and https://pub.dev/packages/photo_manager.

## Verified in this workspace

- Flutter analysis: no issues.
- Automated suite: 14 tests passed.
- Android release APK and iOS simulator builds succeeded.
- iPhone simulator launch verified visually.
- Android debug manifest inspected with aapt: `INTERNET` is present for the authenticated localhost VM service. Release APK permissions inspected with aapt: no Internet or network-state permission.
- Debug launch verified on the Samsung S21 over wireless ADB; Flutter connected to the localhost VM service.
- Camera, gallery deletion, microphone and face-down sensor acceptance testing on physical devices remains necessary.

The APK is a development-signed release build. Production distribution requires your own signing configuration.
