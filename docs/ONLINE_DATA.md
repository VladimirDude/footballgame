# Online Data (Firebase) — Setup & Operations

The app is **offline-first**: it ships a bundled seed of the data and refreshes it
over the air from a CDN. This document explains how to turn the online path on
with Firebase and how to publish data updates without an App Store release.

## What's already built (Phase 1 — in the app, build-green, no SDK)

| File | Role |
|------|------|
| `RemoteDataConfig.swift` | The on/off switch — manifest URL + image URL templates. All `nil` today = offline. |
| `RemoteDataSource.swift` | `URLSession` HTTPS client + versioned disk cache (`DataCache`) in Application Support. |
| `RemoteDataRepository.swift` | Offline-first resolution (cache → bundle) + background `refreshIfNeeded()` + remote image fetch. |
| `ClubDataStore` | Now reads `RemoteDataRepository.shared.currentDatabaseURL` instead of a hardcoded bundle path. |
| `PortraitStore.loadImageAsync` | bundle → remote CDN (disk-cached) fallback for portraits. |
| `testApp` | Kicks off `refreshIfNeeded()` on a background task at launch. |

Because Firebase **Storage serves plain HTTPS URLs**, this whole layer works
against Firebase with **no Firebase SDK** — you only add the SDK for Phase 2
(Remote Config flags, Firestore real-time, entitlement sync).

## Data model on the CDN

Publish four things to Firebase Storage (or any CDN):

```
manifest.json                 # tiny; checked every launch
ClubDatabase.json             # 1.4MB; downloaded only when manifest.version increases
portraits/{playerId}.heic     # 5,327 files (optional — can stay bundled)
logos/{clubId}.png            # 184 files (optional — can stay bundled)
```

`manifest.json`:
```json
{
  "version": 42,
  "updatedAt": "2026-07-24T10:00:00Z",
  "database": {
    "url": "https://firebasestorage.googleapis.com/v0/b/BUCKET/o/ClubDatabase.json?alt=media",
    "sha256": "<hex digest of ClubDatabase.json>"
  },
  "portraitURLTemplate": "https://firebasestorage.googleapis.com/v0/b/BUCKET/o/portraits%2F{id}.heic?alt=media",
  "logoURLTemplate": "https://firebasestorage.googleapis.com/v0/b/BUCKET/o/logos%2F{id}.png?alt=media"
}
```
`{id}` is substituted by the app. Note `/` is URL-encoded as `%2F` in Storage paths.

## Turning it on

1. **Create a Firebase project** and enable **Storage**. Note the bucket name.
2. **Publish the data** (see pipeline below) so the four items above exist.
3. **Set the switch** in `RemoteDataConfig.swift`:
   ```swift
   static let manifestURL = URL(string: "https://firebasestorage.googleapis.com/v0/b/BUCKET/o/manifest.json?alt=media")
   ```
   (The image templates can be left `nil` and driven by the manifest instead.)
4. Ship once. From then on, roster updates need **no app release** — just republish `ManifestVersion+1`.

## Publishing pipeline (extends your existing scripts)

Your `scripts/fetch_*.py` already generate `ClubDatabase.json` + images. Add a
final upload step:

```
run scripts → produce ClubDatabase.json + portraits/ + logos/
  → compute sha256(ClubDatabase.json)
  → write manifest.json with version = previous + 1
  → upload all to Firebase Storage (gsutil / firebase CLI / SDK)
```

To also shrink the app binary further, once images are hosted you can **drop
`PlayerPortraits/` from the bundle** and keep only a small "starter set" (e.g.
the elite-club players used by the games). `PortraitStore.loadImageAsync` will
fetch the rest from the CDN and disk-cache them.

## Phase 2 — add the Firebase SDK (needs your project)

Add via **SPM**: `https://github.com/firebase/firebase-ios-sdk` → products
`FirebaseAnalytics`, `FirebaseCrashlytics`, `FirebaseRemoteConfig`
(+ `FirebaseFirestore` only if you want real-time per-club updates). Drop your
`GoogleService-Info.plist` into the app target and call
`FirebaseApp.configure()` in `testApp.init`.

Then these drop-in adapters light up (write them guarded so the app still builds
without the SDK):

```swift
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
final class FirebaseAnalyticsBackend: AnalyticsBackend {
    func log(name: String, parameters: [String: Any]) { Analytics.logEvent(name, parameters: parameters) }
    func setUserProperty(_ value: String?, for key: String) { Analytics.setUserProperty(value, forName: key) }
}
// at launch: AnalyticsService.shared.register(FirebaseAnalyticsBackend())
#endif
```

```swift
#if canImport(FirebaseRemoteConfig)
// Drive FeatureCatalog.premiumFeatures + paywall pricing/copy from Remote Config
// so you can A/B test what's premium without an app update.
#endif
```

**Remember to update `PrivacyInfo.xcprivacy`** when Analytics/Crashlytics land —
declare the collected data types (and Firebase's own manifest is bundled with
the SDK).

## Why this design

- **Instant launch, works offline** — the read path is synchronous off the cache/bundle; the network is never on the critical path.
- **Cheap checks** — only the tiny manifest is fetched each launch; the 1.4MB DB downloads only on a version bump.
- **Low-risk rollout** — "download now, apply next launch" avoids rewriting the synchronous `ClubDataStore` read path.
- **Integrity** — optional SHA-256 validation of the downloaded database.
- **One ecosystem** — the same Firebase project later powers analytics, Crashlytics, Remote Config flags, and (optionally) server-side subscription entitlements.
