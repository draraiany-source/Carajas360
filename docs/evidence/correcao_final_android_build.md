# Correcao Final — Android release builds

**Result: PASS**

Version: `1.0.0+402` (unchanged)
Commit: `1ac2045fcdd8796c5f8eef29ba7a6ca50e51b5a0` (`1ac2045`)
Branch: `fix/correcao-completa-final`
JAVA_HOME used: `C:\Program Files\Android\Android Studio\jbr` (OpenJDK 21)
GRADLE_USER_HOME: `C:\Users\Lenovo\.gradle`
org.gradle.jvmargs during this retest: `-Xmx2g` (temporarily lowered from `-Xmx4g` after JVM native OOM / disk-full; restored to `-Xmx4g` after successful builds)

## Commands
1. `flutter pub get`
2. `flutter build apk --release` → exit 0
3. `flutter build appbundle --release` → exit 0

## Artifacts

| Artifact | Path | Size (bytes) | SHA256 |
|----------|------|--------------|--------|
| APK | `build\app\outputs\flutter-apk\app-release.apk` | 81900337 | 7BFF7E8FAA875F06FABF752224B2A95F75035697003CEDE7EEDF818500CEC069 |
| AAB | `build\app\outputs\bundle\release\app-release.aab` | 76951191 | C13110A65C8D0462F0CA924E93D6E917FC0DA1A517F8B5C43AD52AE88B45FDC1 |

APK also reported by Flutter as **78.1MB**. AAB reported as **73.4MB**.

## Notes
- No payments enable / deploy / publish.
- Disk was at 0 free during first APK attempt (`Espaço insuficiente no disco`); freed ~3.8GB by removing `build/`, `android/.gradle`, cursor sandbox Gradle cache, and Gradle transforms before successful rebuild.
- First daemon crash: native mmap OOM with `-Xmx4g` under memory pressure.
