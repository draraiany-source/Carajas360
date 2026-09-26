# Fase 7 — Android release builds

**Result: PASS**

Version: `1.0.0+402` (unchanged)
minifyEnabled: false (unchanged)
JAVA_HOME used: `C:\Program Files\Android\Android Studio\jbr` (OpenJDK 21)

## Commands
1. `cd android; .\gradlew --stop` (JAVA_HOME was missing initially; set before builds)
2. `flutter pub get`
3. `flutter build apk --release` → exit 0
4. `flutter build appbundle --release` → exit 0

## Artifacts

| Artifact | Path | Size (bytes) | SHA256 |
|----------|------|--------------|--------|
| APK | `build\app\outputs\flutter-apk\app-release.apk` | 81900337 | C27C2994BC414495AE4E0A21F592C3359E0EC5B99154EDA520ED71F2EC7CDB3F |
| AAB | `build\app\outputs\bundle\release\app-release.aab` | 76950847 | F3A9D13591570F1FFB9DC175504148758779ECAD01B5E816FF58F42B10AE74C2 |

APK also reported by Flutter as **78.1MB**. AAB reported as **73.4MB**.

## Notes
- No `flutter clean` (time-critical skip per Phase 7 resume).
- Hosting deploy / payments / publish / Phase 8 not started.
